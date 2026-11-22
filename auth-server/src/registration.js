import { randomInt, randomUUID, timingSafeEqual } from "node:crypto";
import bcrypt from "bcryptjs";
import express from "express";
import { normalizeEmail } from "./password-reset.js";
import { boundedBcryptInput, PasswordSecurityError, passwordGuards, passwordSecurityErrors } from "./password-security.js";
import { validateQuestions, hashQuestions, writeQuestions } from "./security-questions.js";

const INVALID_CODE = "Invalid or expired registration code. Request a new code.";
const EXPIRED_REGISTRATION = "This registration has expired. Return to Register and try again.";
const SEND_COOLDOWN = 60;

export function registrationRouter({ pool, secret, codeSecret, mailer, clean, parseBirthDate, publicUser }) {
  const router = express.Router();
  const guards = passwordGuards({ pool, secret });
  const codes = passwordGuards({ pool, secret: codeSecret });
  const digest = (email, requestId, code) => codes.key("registration-code", `${email}:${requestId}:${code}`);

  function requireConfiguration(sending = false) {
    if (typeof codeSecret !== "string" || codeSecret.length < 32 || (sending && !mailer.configured)) {
      throw new PasswordSecurityError(503, "Registration email verification is unavailable. Please contact the administrator.");
    }
  }

  async function rateLimit(scope, identity, maximum, seconds) {
    try {
      await guards.rateLimit(scope, identity, maximum, seconds);
    } catch (error) {
      if (!(error instanceof PasswordSecurityError) || error.status !== 429) throw error;
      const message = seconds === SEND_COOLDOWN
        ? "Please wait 60 seconds before requesting another registration code."
        : "Too many registration requests. Please try again later.";
      throw new PasswordSecurityError(429, message, seconds);
    }
  }

  async function limitEmail(email) {
    await rateLimit("registration-send-minute", email, 1, SEND_COOLDOWN);
    await rateLimit("registration-send-hour", email, 5, 3600);
  }

  function newCode(email, previous) {
    let code;
    do {
      code = String(randomInt(0, 1_000_000)).padStart(6, "0");
    } while (previous && digest(email, previous.request_id, code) === previous.code_hash);
    const requestId = randomUUID();
    return { code, requestId, hash: digest(email, requestId, code) };
  }

  function validRegistrationId(id) {
    if (typeof id !== "string" || !/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(id)) {
      throw new PasswordSecurityError(400, EXPIRED_REGISTRATION);
    }
    return id;
  }

  async function send(email, registrationId, { code, requestId }) {
    try {
      await mailer.sendRegistrationCode(email, code, requestId);
    } catch {
      throw new PasswordSecurityError(503,
        "The mail service did not confirm sending a registration code. Please wait 60 seconds and try again.",
        SEND_COOLDOWN);
    }
    const accepted = await pool.query(
      "UPDATE pending_registrations SET accepted = true WHERE registration_id = $1 AND request_id = $2 RETURNING registration_id",
      [registrationId, requestId],
    );
    if (!accepted.rows.length) throw new PasswordSecurityError(400, EXPIRED_REGISTRATION);
    return { registrationId, retryAfterSeconds: SEND_COOLDOWN };
  }

  router.post("/register", async (req, res, next) => {
    try {
      const body = req.body ?? {};
      const fullName = clean(body.fullName);
      const birthDate = parseBirthDate(body.birthDate);
      const interest = clean(body.interest) || null;
      const username = clean(body.username);
      const phone = clean(body.phone);
      const password = typeof body.password === "string" ? body.password : "";
      // Keep the existing optional security question rules.
      if (clean(body.securityQuestion) || clean(body.securityAnswer)) {
        throw new PasswordSecurityError(400, "Please configure three security questions, or leave them all empty.");
      }
      const questions = validateQuestions(body.securityQuestions, { optional: true });
      if (!fullName || !birthDate || !username || !clean(body.email) || !phone || !password) {
        throw new PasswordSecurityError(400, "Please complete all required registration fields.");
      }
      if (password.length < 6) {
        throw new PasswordSecurityError(400, "Password must contain at least 6 characters.");
      }
      if (phone.replace(/\D/g, "").length < 8) {
        throw new PasswordSecurityError(400, "Enter a valid phone number.");
      }
      let email;
      try { email = normalizeEmail(body.email); }
      catch { throw new PasswordSecurityError(400, "Enter a valid email address."); }

      await rateLimit("registration-send-ip", req.ip, 20, 3600);
      const existing = await pool.query(
        "SELECT 1 FROM users WHERE lower(email) = $1 OR lower(username) = lower($2) LIMIT 1",
        [email, username],
      );
      if (existing.rows.length) throw new PasswordSecurityError(409, "Email or username is already registered.");
      requireConfiguration(true);
      await limitEmail(email);
      const details = {
        fullName, birthDate, interest, username, phone,
        passwordHash: await bcrypt.hash(boundedBcryptInput(password), 12),
        questions: await hashQuestions(questions),
      };
      const registrationId = randomUUID();
      const delivery = await guards.transaction(async (client) => {
        const previous = await client.query(
          "SELECT request_id, code_hash FROM pending_registrations WHERE email = $1 FOR UPDATE", [email],
        );
        const delivery = newCode(email, previous.rows[0]);
        await client.query(
          `INSERT INTO pending_registrations (email, registration_id, request_id, details, code_hash, code_expires_at, expires_at)
           VALUES ($1, $2, $3, $4, $5, clock_timestamp() + interval '10 minutes', clock_timestamp() + interval '30 minutes')
           ON CONFLICT (email) DO UPDATE SET registration_id = EXCLUDED.registration_id, request_id = EXCLUDED.request_id,
             details = EXCLUDED.details, code_hash = EXCLUDED.code_hash, code_expires_at = EXCLUDED.code_expires_at,
             expires_at = EXCLUDED.expires_at, attempts = 0, accepted = false`,
          [email, registrationId, delivery.requestId, details, delivery.hash],
        );
        return delivery;
      });
      res.status(202).json(await send(email, registrationId, delivery));
    } catch (error) { next(error); }
  });

  router.post("/register/resend", async (req, res, next) => {
    try {
      requireConfiguration(true);
      const id = validRegistrationId(req.body?.registrationId);
      await rateLimit("registration-send-ip", req.ip, 20, 3600);
      const pending = await pool.query(
        "SELECT email FROM pending_registrations WHERE registration_id = $1 AND expires_at > clock_timestamp()", [id],
      );
      if (!pending.rows.length) throw new PasswordSecurityError(400, EXPIRED_REGISTRATION);
      const { email } = pending.rows[0];
      await limitEmail(email);
      const delivery = await guards.transaction(async (client) => {
        const result = await client.query(
          `SELECT request_id, code_hash FROM pending_registrations
           WHERE registration_id = $1 AND expires_at > clock_timestamp() FOR UPDATE`, [id],
        );
        if (!result.rows.length) return new PasswordSecurityError(400, EXPIRED_REGISTRATION);
        const delivery = newCode(email, result.rows[0]);
        await client.query(
          `UPDATE pending_registrations SET request_id = $2, code_hash = $3, attempts = 0, accepted = false,
             code_expires_at = clock_timestamp() + interval '10 minutes', expires_at = clock_timestamp() + interval '30 minutes'
           WHERE registration_id = $1`,
          [id, delivery.requestId, delivery.hash],
        );
        return delivery;
      });
      res.status(202).json(await send(email, id, delivery));
    } catch (error) { next(error); }
  });

  router.post("/register/verify", async (req, res, next) => {
    try {
      requireConfiguration();
      const id = validRegistrationId(req.body?.registrationId);
      const { code } = req.body;
      await rateLimit("registration-verify-ip", req.ip, 100, 900);
      if (typeof code !== "string" || !/^\d{6}$/.test(code)) {
        throw new PasswordSecurityError(400, "Enter the 6-digit registration code.");
      }
      const user = await guards.transaction(async (client) => {
        const result = await client.query(
          `SELECT *, code_expires_at > clock_timestamp() AS active FROM pending_registrations
           WHERE registration_id = $1 AND expires_at > clock_timestamp() FOR UPDATE`, [id],
        );
        const pending = result.rows[0];
        if (!pending || !pending.active || !pending.accepted) return new PasswordSecurityError(400, INVALID_CODE);
        if (pending.attempts >= 5) return new PasswordSecurityError(400, "Too many incorrect codes. Request a new code.");
        const expected = Buffer.from(pending.code_hash, "hex");
        const submitted = Buffer.from(digest(pending.email, pending.request_id, code), "hex");
        if (!timingSafeEqual(expected, submitted)) {
          await client.query("UPDATE pending_registrations SET attempts = attempts + 1 WHERE registration_id = $1", [id]);
          return new PasswordSecurityError(400, pending.attempts === 4 ? "Too many incorrect codes. Request a new code." : INVALID_CODE);
        }
        const { fullName, birthDate, interest, username, phone, passwordHash, questions } = pending.details;
        const inserted = await client.query(
          `INSERT INTO users (full_name, birth_date, interest, username, email, phone, password_hash, auth_provider)
           VALUES ($1,$2,$3,$4,$5,$6,$7,'local') ON CONFLICT DO NOTHING RETURNING *`,
          [fullName, birthDate, interest, username, pending.email, phone, passwordHash],
        );
        await client.query("DELETE FROM pending_registrations WHERE registration_id = $1", [id]);
        if (!inserted.rows.length) return new PasswordSecurityError(409, "Email or username is already registered.");
        if (questions.length) await writeQuestions(client, inserted.rows[0].id, questions);
        return inserted.rows[0];
      });
      res.status(201).json({ user: publicUser(user) });
    } catch (error) { next(error); }
  });

  router.use("/register", passwordSecurityErrors);
  return router;
}
