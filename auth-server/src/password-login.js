import bcrypt from "bcryptjs";
import { boundedBcryptInput, PasswordSecurityError, passwordGuards, passwordSecurityErrors } from "./password-security.js";

const INVALID_LOGIN = "Invalid username/email or password.";
const LOCK_SECONDS = 300;
const IP_MAX = 60;
// Match the normal bcrypt cost even when the identifier has no password hash.
const DUMMY_HASH = "$2a$12$BtDhU33jKc/JfKMoCMKVOOh7ZByGgyBFvtMUbyMuk/F2fuJZI3CKG";
const REMAINING = "GREATEST(0, CEIL(EXTRACT(EPOCH FROM expires_at - clock_timestamp())))::int AS retry";

function limited(seconds) {
  const minutes = Math.ceil(seconds / 60);
  return new PasswordSecurityError(429,
    `Too many failed login attempts. Please try again in ${minutes} ${minutes === 1 ? "minute" : "minutes"}.`, seconds);
}

export function passwordLoginHandler({ pool, secret, clean, authResponse }) {
  const guards = passwordGuards({ pool, secret });
  async function limitIp(ip) {
    const result = await pool.query(
      `INSERT INTO auth_rate_limits AS limits (key, hits, expires_at)
       VALUES ($1, 1, clock_timestamp() + $2 * interval '1 second')
       ON CONFLICT (key) DO UPDATE SET
         hits = CASE WHEN limits.expires_at <= clock_timestamp() THEN 1 ELSE LEAST(limits.hits + 1, $3 + 1) END,
         expires_at = CASE WHEN limits.expires_at <= clock_timestamp()
           THEN clock_timestamp() + $2 * interval '1 second' ELSE limits.expires_at END
       RETURNING hits, ${REMAINING}`,
      [guards.key("login-ip", ip), LOCK_SECONDS, IP_MAX],
    );
    if (result.rows[0].hits > IP_MAX) throw limited(Math.max(1, result.rows[0].retry));
  }

  return async (req, res) => {
    try {
      await limitIp(req.ip);
      const account = clean(req.body?.account);
      const password = typeof req.body?.password === "string" ? req.body.password : "";
      if (!account || !password) throw new PasswordSecurityError(400, "Username/email and password are required.");

      const user = await guards.transaction(async (client) => {
        const result = await client.query(
          `SELECT id, password_hash FROM users
           WHERE lower(email) = lower($1) OR lower(username) = lower($1) LIMIT 1`, [account],
        );
        const candidate = result.rows[0];
        const identity = candidate ? `user:${candidate.id}` : `missing:${account.toLowerCase()}`;
        const key = guards.key("login-account", identity);
        // Lock the counter, including for missing identifiers, before comparing the password.
        const state = (await client.query(
          `INSERT INTO auth_rate_limits (key, hits, expires_at)
           VALUES ($1, 0, clock_timestamp())
           ON CONFLICT (key) DO UPDATE SET key = EXCLUDED.key
           RETURNING hits, ${REMAINING}`, [key],
        )).rows[0];
        if (state.hits >= 5 && state.retry > 0) return limited(state.retry);

        const valid = await bcrypt.compare(boundedBcryptInput(password), candidate?.password_hash || DUMMY_HASH);
        if (!candidate?.password_hash || !valid) {
          const hits = (state.retry > 0 ? state.hits : 0) + 1;
          const seconds = hits >= 5 ? LOCK_SECONDS : 900;
          await client.query(
            "UPDATE auth_rate_limits SET hits = $2, expires_at = clock_timestamp() + $3 * interval '1 second' WHERE key = $1",
            [key, hits, seconds],
          );
          return hits >= 5 ? limited(LOCK_SECONDS) : new PasswordSecurityError(401, INVALID_LOGIN);
        }
        const updated = await client.query(
          `UPDATE users SET last_login_at = now(), updated_at = now()
           WHERE id = $1 AND password_hash = $2 RETURNING *`,
          [candidate.id, candidate.password_hash],
        );
        if (!updated.rows.length) return new PasswordSecurityError(401, INVALID_LOGIN);
        await guards.clear(client, "login-account", identity);
        return updated.rows[0];
      });
      res.json(authResponse(user));
    } catch (error) {
      if (error instanceof PasswordSecurityError && error.retryAfterSeconds) {
        res.set("Access-Control-Expose-Headers", "Retry-After");
      }
      passwordSecurityErrors(error, req, res);
    }
  };
}
