import assert from "node:assert/strict";
import { test } from "node:test";
import { createMailer } from "../src/mailer.js";

const QQ = { SMTP_USER: "qq-sender@qq.com", SMTP_PASS: "test-qq-pass" };
const OUTLOOK = {
  OUTLOOK_SENDER_EMAIL: "graph-sender@outlook.com",
  OUTLOOK_CLIENT_ID: "test-client-id",
  OUTLOOK_REFRESH_TOKEN: "test-refresh-token",
};
const to = "another-user@yahoo.com";
const code = "654321";
const smtpRejection = () => Object.assign(new Error(`550 ${to} rejected`), {
  code: "EENVELOPE", responseCode: 550, command: "RCPT TO",
});

function setup(env, { sendMail, sendGraph, exchangeToken } = {}) {
  const calls = [];
  const logs = [];
  const mailer = createMailer(env, () => ({
    async sendMail(mail) {
      calls.push(["qq", mail]);
      return sendMail ? sendMail(mail) : { accepted: [to] };
    },
  }), {
    logger: { info: (_, entry) => logs.push(entry), warn: (_, entry) => logs.push(entry) },
    async fetcher(url, options) {
      if (url.endsWith("/token")) {
        calls.push(["token", options.body]);
        return exchangeToken ? exchangeToken() :
          Response.json({ access_token: "test-access-token", expires_in: 3600 });
      }
      assert.equal(url, "https://graph.microsoft.com/v1.0/me/sendMail");
      assert.equal(options.method, "POST");
      assert.equal(options.headers.Authorization, "Bearer test-access-token");
      calls.push(["outlook", JSON.parse(options.body)]);
      return sendGraph ? sendGraph() : new Response(null, { status: 202 });
    },
  });
  return { mailer, calls, logs, providers: () => calls.map(([name]) => name) };
}

test("QQ accepts one non-QQ recipient, independently of incomplete Outlook settings", async () => {
  const { mailer, calls, logs, providers } = setup({ ...QQ, OUTLOOK_CLIENT_ID: "incomplete" });
  assert.equal(mailer.configured, true);
  await mailer.sendCode(to, code, "test-request-id");
  assert.deepEqual(providers(), ["qq"]);
  assert.deepEqual(calls[0][1].to, { address: to, name: "" });
  assert.match(calls[0][1].text, new RegExp(code));
  assert.equal(logs[0].outcome, "accepted");
});

test("QQ explicit rejection is reported and logs exclude recipients, secrets and codes", async () => {
  const { mailer, logs } = setup(QQ, { sendMail() { throw smtpRejection(); } });
  await assert.rejects(mailer.sendCode(to, code), {
    definitive: true, category: "rejected", status: 550,
  });
  assert.equal(logs[0].outcome, "failed");
  assert.doesNotMatch(JSON.stringify(logs), /@|654321|test-qq-pass|550 .*rejected/);
});

test("Outlook uses delegated OAuth and Graph can accept mail with QQ disabled", async () => {
  const { mailer, calls, logs, providers } = setup(OUTLOOK);
  assert.equal(mailer.configured, true);
  await Promise.all([mailer.sendCode(to, code), mailer.sendCode("second@icloud.com", "123456")]);
  assert.deepEqual(providers(), ["token", "outlook", "outlook"]);
  assert.equal(calls[0][1].get("grant_type"), "refresh_token");
  assert.equal(calls[0][1].get("client_id"), OUTLOOK.OUTLOOK_CLIENT_ID);
  assert.equal(calls[0][1].get("refresh_token"), OUTLOOK.OUTLOOK_REFRESH_TOKEN);
  assert.equal(calls[0][1].get("scope"), "https://graph.microsoft.com/Mail.Send offline_access");
  const messages = calls.slice(1).map(([, payload]) => payload.message);
  assert.deepEqual(messages.map((message) => message.toRecipients[0].emailAddress.address).sort(),
    [to, "second@icloud.com"]);
  const message = messages.find((item) => item.toRecipients[0].emailAddress.address === to);
  assert.equal(message.from.emailAddress.address, OUTLOOK.OUTLOOK_SENDER_EMAIL);
  assert.match(message.body.content, new RegExp(code));
  assert.match(message.body.content, /10 minutes/);
  assert.ok(logs.every((entry) => entry.outcome === "accepted" && entry.status === 202));
});

test("Outlook explicit rejection is reported without logging tokens or raw Graph errors", async () => {
  const { mailer, logs } = setup(OUTLOOK, {
    sendGraph: () => Response.json({ error: `${to}: test-access-token` }, { status: 403 }),
  });
  await assert.rejects(mailer.sendCode(to, code), { definitive: true, category: "rejected", status: 403 });
  assert.doesNotMatch(JSON.stringify(logs), /@|654321|test-access-token|test-refresh-token/);
});

test("QQ rejection falls back to configured Outlook with the original code and message", async () => {
  const { mailer, calls, providers } = setup({ ...QQ, ...OUTLOOK }, { sendMail() { throw smtpRejection(); } });
  await mailer.sendCode(to, code);
  assert.deepEqual(providers(), ["qq", "token", "outlook"]);
  assert.equal(calls[0][1].text, calls[2][1].message.body.content);
});

test("registration email uses the same QQ and Outlook routing with a distinct purpose", async () => {
  const { mailer, calls, logs, providers } = setup({ ...QQ, ...OUTLOOK }, {
    sendMail() { throw smtpRejection(); },
  });
  await mailer.sendRegistrationCode(to, code, "registration-request");
  assert.deepEqual(providers(), ["qq", "token", "outlook"]);
  const message = calls[2][1].message;
  assert.match(message.subject, /registration verification code/i);
  assert.match(message.body.content, /654321/);
  assert.doesNotMatch(message.body.content, /password reset/i);
  assert.equal(calls[0][1].text, message.body.content);
  assert.doesNotMatch(JSON.stringify(logs), /@|654321|test-qq-pass|test-access-token/);
});

test("a proven SMTP connection failure allows fallback", async () => {
  const { mailer, logs, providers } = setup({ ...QQ, ...OUTLOOK }, {
    sendMail() { throw Object.assign(new Error("test refusal"), { code: "ESOCKET", syscall: "connect" }); },
  });
  await mailer.sendCode(to, code);
  assert.deepEqual(providers(), ["qq", "token", "outlook"]);
  assert.equal(logs[0].category, "connection");
  assert.equal(logs[0].outcome, "failed");
});

test("Outlook preference and pre-send OAuth failure permit a single QQ fallback", async () => {
  const { mailer, logs, providers } = setup({ ...QQ, ...OUTLOOK, MAIL_PRIMARY_PROVIDER: "outlook" }, {
    exchangeToken: () => Response.json({ error: "invalid_grant" }, { status: 400 }),
  });
  await mailer.sendCode(to, code);
  assert.deepEqual(providers(), ["token", "qq"]);
  assert.equal(logs[0].phase, "token");
  assert.equal(logs[0].category, "authorization");
});

test("if both providers fail definitively the request fails after one attempt per provider", async () => {
  const { mailer, providers } = setup({ ...QQ, ...OUTLOOK }, {
    sendMail() { throw smtpRejection(); },
    sendGraph: () => new Response(null, { status: 429 }),
  });
  await assert.rejects(mailer.sendCode(to, code), { definitive: true, category: "rate_limit", status: 429 });
  assert.deepEqual(providers(), ["qq", "token", "outlook"]);
});

test("a successful primary provider never sends again through the backup", async () => {
  for (const [primary, expected] of [["qq", ["qq"]], ["outlook", ["token", "outlook"]]]) {
    const { mailer, providers } = setup({ ...QQ, ...OUTLOOK, MAIL_PRIMARY_PROVIDER: primary });
    await mailer.sendCode(to, code);
    assert.deepEqual(providers(), expected);
  }
});

test("ambiguous SMTP socket timeout does not retry through Outlook", async () => {
  const { mailer, logs, providers } = setup({ ...QQ, ...OUTLOOK }, {
    sendMail() { throw Object.assign(new Error("Timeout after DATA"), { code: "ETIMEDOUT", command: "CONN" }); },
  });
  await assert.rejects(mailer.sendCode(to, code), { definitive: false, category: "timeout" });
  assert.deepEqual(providers(), ["qq"]);
  assert.equal(logs[0].outcome, "unknown");
});

test("ambiguous Graph server and network failures do not retry through QQ", async () => {
  for (const sendGraph of [
    () => new Response(null, { status: 502 }),
    () => { throw new TypeError("Connection lost after submit"); },
  ]) {
    const { mailer, providers } = setup({ ...QQ, ...OUTLOOK, MAIL_PRIMARY_PROVIDER: "outlook" }, { sendGraph });
    await assert.rejects(mailer.sendCode(to, code), { definitive: false });
    assert.deepEqual(providers(), ["token", "outlook"]);
  }
});
