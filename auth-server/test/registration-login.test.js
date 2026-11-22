import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";
import { readFile } from "node:fs/promises";
import bcrypt from "bcryptjs";
import express from "express";
import pg from "pg";
import { PGlite } from "@electric-sql/pglite";
import { passwordGuards } from "../src/password-security.js";
import { registrationRouter } from "../src/registration.js";
import { passwordLoginHandler } from "../src/password-login.js";
import { createPasswordReset } from "../src/password-reset.js";

const secret = "test-login-and-registration-key";
const codeSecret = "test-only-code-secret-at-least-32-characters";
const password = "student-password";
const ip = "127.0.0.1";
const input = (email = "student@outlook.com", username = "new-student") => ({
  fullName: "New Student", birthDate: "2000-01-01", email, username,
  phone: "123456789", password,
});
let db, pool, legacy, legacyHash, mailFails, sent;
const servers = [];
let tail = Promise.resolve();

async function acquire() {
  const prior = tail;
  let release;
  tail = new Promise((resolve) => { release = resolve; });
  await prior;
  return release;
}

async function post(path, body, instance = 0, headers = {}) {
  const port = servers[instance].address().port;
  const response = await fetch(`http://${ip}:${port}/auth${path}`, {
    method: "POST", headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json(), headers: response.headers };
}

async function begin(data = input()) {
  const response = await post("/register", data);
  assert.equal(response.status, 202);
  assert.deepEqual(Object.keys(response.body).sort(), ["registrationId", "retryAfterSeconds"]);
  assert.equal(response.body.retryAfterSeconds, 60);
  return { registrationId: response.body.registrationId, code: sent.at(-1).code };
}

const login = (account, value = "wrong-password", instance) => post("/login", { account, password: value }, instance);
const verify = (data, instance) => post("/register/verify", data, instance);
const expireSendCooldown = async (email) => {
  await pool.query("UPDATE auth_rate_limits SET expires_at = now() - interval '1 second' WHERE key = $1",
    [passwordGuards({ pool, secret }).key("registration-send-minute", email)]);
};
const loginKey = (scope, identity) => passwordGuards({ pool, secret }).key(scope, identity);

before(async () => {
  const url = process.env.AUTH_TEST_DATABASE_URL;
  if (url) {
    if (new URL(url).pathname !== "/gv_auth_test") throw new Error("Only isolated gv_auth_test is allowed.");
    pool = new pg.Pool({ connectionString: url });
  } else {
    db = new PGlite();
    const query = async (sql, args) => {
      const result = await db.query(sql, args);
      return { ...result, rowCount: result.fields?.length ? result.rows.length : result.affectedRows };
    };
    pool = {
      async query(sql, args) {
        const release = await acquire();
        try { return await query(sql, args); } finally { release(); }
      },
      async connect() { return { query, release: await acquire() }; },
    };
  }
  for (const path of ["../db/init.sql", "../src/reset-schema.sql", "../src/security-question-schema.sql",
    "../src/registration-schema.sql", "../src/registration-schema.sql"]) {
    const sql = (await readFile(new URL(path, import.meta.url), "utf8")).replace("CREATE EXTENSION IF NOT EXISTS pgcrypto;", "");
    if (db) await db.exec(sql); else await pool.query(sql);
  }
  legacyHash = await bcrypt.hash(password, 4);
  const mailer = {
    configured: true,
    async sendRegistrationCode(email, code) {
      sent.push({ email, code });
      if (mailFails) throw new Error("Simulated SMTP rejection");
    },
  };
  const clean = (value) => typeof value === "string" ? value.trim() : "";
  for (let i = 0; i < 2; i++) {
    const app = express();
    app.use(express.json());
    app.use("/auth", registrationRouter({ pool, secret, codeSecret, mailer, clean,
      parseBirthDate: (value) => value === "2000-01-01" ? value : null,
      publicUser: ({ id, email }) => ({ id, email }),
    }));
    app.post("/auth/login", passwordLoginHandler({ pool, secret, clean, authResponse: ({ id }) => ({ id }) }));
    servers.push(await new Promise((resolve) => {
      const server = app.listen(0, ip, () => resolve(server));
    }));
  }
});

beforeEach(async () => {
  sent = [];
  mailFails = false;
  await pool.query("TRUNCATE users, pending_registrations, auth_rate_limits CASCADE");
  legacy = (await pool.query(
    "INSERT INTO users (full_name, email, username, password_hash) VALUES ('Legacy', 'legacy@example.com', 'legacy', $1) RETURNING *",
    [legacyHash],
  )).rows[0];
});

after(async () => {
  for (const server of servers) await new Promise((resolve) => server.close(resolve));
  if (db) await db.close(); else if (pool) await pool.end();
});

test("QQ, Outlook and Yahoo addresses verify and can then log in", async () => {
  for (const domain of ["qq.com", "outlook.com", "yahoo.com"]) {
    const data = input(`student@${domain}`, domain);
    const pending = await begin(data);
    assert.equal(sent.at(-1).email, data.email);
    assert.match(pending.code, /^\d{6}$/);
    const stored = (await pool.query("SELECT * FROM pending_registrations WHERE email = $1", [data.email])).rows[0];
    assert.equal(stored.code_hash.length, 64);
    assert.notEqual(stored.code_hash, pending.code);
    assert.notEqual(stored.details.passwordHash, password);
    assert.equal(stored.details.password, undefined);
    assert.equal((await verify(pending)).status, 201);
    assert.equal((await login(data.email, password)).status, 200);
    assert.equal((await verify(pending)).status, 400);
  }
});

test("other ordinary mailbox domains can start verification", async () => {
  for (const domain of ["hotmail.com", "live.com", "icloud.com", "proton.me", "campus.edu", "business.example"]) {
    const data = input(`student@${domain}`, domain);
    await begin(data);
    assert.equal(sent.at(-1).email, data.email);
  }
});

test("an abandoned registration cannot log in, and an expired flow does not reserve the email", async () => {
  const first = await begin();
  assert.equal((await login(input().username, password)).status, 401);
  assert.equal((await pool.query("SELECT 1 FROM users WHERE email = $1", [input().email])).rowCount, 0);
  await pool.query("UPDATE pending_registrations SET expires_at = now() - interval '1 second'");
  await expireSendCooldown(input().email);
  const restarted = await begin();
  assert.notEqual(restarted.registrationId, first.registrationId);
  assert.equal((await verify(first)).status, 400);
  assert.equal((await verify(restarted)).status, 201);
});

test("wrong, expired and unconfirmed codes cannot create an account; five wrong codes lock the challenge", async () => {
  const pending = await begin();
  const wrong = pending.code === "000000" ? "111111" : "000000";
  for (let i = 0; i < 5; i++) {
    const result = await verify({ ...pending, code: wrong });
    assert.equal(result.status, 400);
    if (i === 4) assert.match(result.body.error, /Too many incorrect codes/);
  }
  assert.equal((await verify(pending)).status, 400);
  assert.equal((await pool.query("SELECT attempts FROM pending_registrations")).rows[0].attempts, 5);
  await expireSendCooldown(input().email);
  assert.equal((await post("/register/resend", pending)).status, 202);
  await pool.query("UPDATE pending_registrations SET code_expires_at = now() - interval '1 second'");
  assert.equal((await verify({ ...pending, code: sent.at(-1).code })).status, 400);
  assert.equal((await pool.query("SELECT 1 FROM users WHERE email = $1", [input().email])).rowCount, 0);
});

test("shared email cooldown blocks parallel starts and resend; a resend invalidates the old code", async () => {
  const attempts = await Promise.all([post("/register", input()), post("/register", input(), 1)]);
  assert.deepEqual(attempts.map((response) => response.status).sort(), [202, 429]);
  assert.equal(attempts.find((response) => response.status === 429).headers.get("retry-after"), "60");
  assert.equal(sent.length, 1);
  const registrationId = attempts.find((response) => response.status === 202).body.registrationId;
  const code = sent[0].code;
  assert.equal((await post("/register/resend", { registrationId })).status, 429);
  await expireSendCooldown(input().email);
  assert.equal((await post("/register/resend", { registrationId }, 1)).status, 202);
  assert.notEqual(sent.at(-1).code, code);
  assert.equal((await verify({ registrationId, code })).status, 400);
  assert.equal((await verify({ registrationId, code: sent.at(-1).code })).status, 201);
});

test("failed mail submission cannot activate its code or bypass cooldown", async () => {
  mailFails = true;
  const response = await post("/register", input());
  assert.equal(response.status, 503);
  const pending = (await pool.query("SELECT * FROM pending_registrations")).rows[0];
  assert.equal(pending.accepted, false);
  assert.equal((await verify({ registrationId: pending.registration_id, code: sent[0].code })).status, 400);
  assert.equal((await post("/register", input())).status, 429);
});

test("formal duplicates are rejected and concurrent verification creates only one account", async () => {
  assert.equal((await post("/register", input("LEGACY@example.com"))).status, 409);
  assert.equal((await post("/register", input("fresh@outlook.com", "LEGACY"))).status, 409);
  const pending = await begin();
  const duplicate = await begin(input("other@outlook.com"));
  const attempts = await Promise.all([verify(pending), verify(pending, 1), verify(duplicate, 1)]);
  assert.equal(attempts.filter((response) => response.status === 201).length, 1);
  assert.equal((await pool.query("SELECT 1 FROM users WHERE username = $1", [input().username])).rowCount, 1);
});

test("codes from separate registrations cannot be used on another email", async () => {
  const first = await begin();
  const otherEmail = "other@proton.me";
  let second = await begin(input(otherEmail, "other"));
  if (first.code === second.code) {
    await expireSendCooldown(otherEmail);
    assert.equal((await post("/register/resend", second)).status, 202);
    second = { ...second, code: sent.at(-1).code };
  }
  assert.equal((await verify({ ...second, code: first.code })).status, 400);
  assert.equal((await verify(second)).status, 201);
});

test("registration and Forgot Password codes use independent flows", async () => {
  let resetCode;
  const reset = createPasswordReset({
    pool, secret: codeSecret,
    mailer: { configured: true, async sendCode(_email, code) { resetCode = code; } },
  });
  await reset.requestCode(legacy.email, ip);
  let pending = await begin();
  if (pending.code === resetCode) {
    await expireSendCooldown(input().email);
    assert.equal((await post("/register/resend", pending)).status, 202);
    pending = { ...pending, code: sent.at(-1).code };
  }
  assert.equal((await verify({ ...pending, code: resetCode })).status, 400);
  await assert.rejects(reset.resetPassword(legacy.email, pending.code, "new-password", ip), { status: 400 });
  assert.equal((await verify(pending)).status, 201);
  await reset.resetPassword(legacy.email, resetCode, "new-password", ip);
  assert.equal((await login(legacy.email, "new-password")).status, 200);
});

test("four password failures return 401; aliases share the fifth failure and the lock expires", async () => {
  for (const alias of ["legacy", " LEGACY@example.com ", "LEGACY", "legacy@example.com"]) {
    assert.equal((await login(alias)).status, 401);
  }
  const locked = await login("legacy", "wrong-password", 1);
  assert.equal(locked.status, 429);
  assert.equal(locked.headers.get("retry-after"), "300");
  assert.equal(locked.headers.get("access-control-expose-headers"), "Retry-After");
  assert.equal((await login("legacy@example.com", password, 1)).status, 429);
  await pool.query("UPDATE auth_rate_limits SET expires_at = now() - interval '1 second' WHERE key = $1",
    [loginKey("login-account", `user:${legacy.id}`)]);
  assert.equal((await login("legacy@example.com", password)).status, 200);
});

test("legacy login succeeds without verification state and successful login clears failures", async () => {
  for (let i = 0; i < 4; i++) assert.equal((await login("legacy")).status, 401);
  assert.equal((await login("legacy@example.com", password)).status, 200);
  assert.equal((await pool.query("SELECT 1 FROM auth_rate_limits WHERE key = $1",
    [loginKey("login-account", `user:${legacy.id}`)])).rowCount, 0);
  assert.equal((await login("legacy")).status, 401);
});

test("missing identifiers have the same failures and threshold response as existing accounts", async () => {
  for (let i = 0; i < 5; i++) {
    const [missing, existing] = await Promise.all([login("missing@example.com", password, 1), login("legacy")]);
    assert.equal(missing.status, existing.status);
    assert.deepEqual(missing.body, existing.body);
  }
});

test("IP rate limit works across accounts and ignores a supplied forwarding header", async () => {
  const key = loginKey("login-ip", ip);
  await pool.query("INSERT INTO auth_rate_limits VALUES ($1, 59, now() + interval '2 minutes')", [key]);
  assert.equal((await login("legacy", password)).status, 200);
  const blocked = await post("/login", { account: "other", password }, 1, { "X-Forwarded-For": "203.0.113.1" });
  assert.equal(blocked.status, 429);
  assert.ok(Number(blocked.headers.get("retry-after")) <= 120);
  await pool.query("UPDATE auth_rate_limits SET expires_at = now() - interval '1 second' WHERE key = $1", [key]);
  assert.equal((await login("legacy", password, 1)).status, 200);
});

test("parallel password failures across instances commit exactly five failed attempts", async () => {
  const attempts = await Promise.all(Array.from({ length: 9 }, (_, i) =>
    login(i % 2 ? "legacy" : "legacy@example.com", "wrong-password", i % 2)));
  assert.equal(attempts.filter((response) => response.status === 401).length, 4);
  assert.equal(attempts.filter((response) => response.status === 429).length, 5);
  const state = await pool.query("SELECT hits FROM auth_rate_limits WHERE key = $1",
    [loginKey("login-account", `user:${legacy.id}`)]);
  assert.equal(state.rows[0].hits, 5);
});
