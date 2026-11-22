import { readFile, rename, writeFile, unlink } from "node:fs/promises";
import { setTimeout as sleep } from "node:timers/promises";
import { parseEnv } from "node:util";
import { OUTLOOK_AUTHORITY, OUTLOOK_SCOPE } from "../src/outlook-mailer.js";

const file = process.argv[2] ?? ".env.server";
const tokenLine = /^([ \t]*(?:export[ \t]+)?OUTLOOK_REFRESH_TOKEN[ \t]*=)[^\r\n]*/gm;

async function oauth(endpoint, params) {
  const response = await fetch(`${OUTLOOK_AUTHORITY}/${endpoint}`, {
    method: "POST",
    redirect: "error",
    signal: AbortSignal.timeout(10000),
    body: new URLSearchParams(params),
  });
  return { ok: response.ok, status: response.status, data: await response.json() };
}

async function authorize(clientId) {
  const device = await oauth("devicecode", { client_id: clientId, scope: OUTLOOK_SCOPE });
  if (!device.ok) {
    console.error(`Microsoft rejected the device code request (HTTP ${device.status}).`);
    return;
  }
  const { verification_uri, user_code, device_code, expires_in, interval } = device.data;
  const deadline = Date.now() + expires_in * 1000;
  console.log(`Open ${verification_uri} in your browser and enter ${user_code}.`);
  console.log("Sign in with the Outlook mailbox set in OUTLOOK_SENDER_EMAIL and approve Mail.Send.");
  let wait = Math.max(interval || 5, 5) * 1000;
  while (Date.now() + wait < deadline) {
    await sleep(wait);
    const result = await oauth("token", {
      client_id: clientId,
      grant_type: "urn:ietf:params:oauth:grant-type:device_code",
      device_code,
    });
    if (result.ok) return result.data.refresh_token;
    if (result.data.error === "authorization_pending") continue;
    if (result.data.error === "slow_down") {
      wait += 5000;
      continue;
    }
    console.error(`Microsoft did not complete authorization (HTTP ${result.status}).`);
    return;
  }
  console.error("The device code expired. Run this command again.");
}

async function main() {
  if (![".env.server", ".env"].includes(file)) {
    console.error("Run from the project root with .env.server or .env.");
    return false;
  }
  const env = parseEnv(await readFile(file, "utf8"));
  const { OUTLOOK_CLIENT_ID: clientId, OUTLOOK_SENDER_EMAIL: sender } = env;
  if (!clientId || !sender) {
    console.error(`Set OUTLOOK_CLIENT_ID and OUTLOOK_SENDER_EMAIL in ${file} first.`);
    return false;
  }
  const token = await authorize(clientId);
  if (!token || /['\r\n]/.test(token)) {
    console.error("No usable refresh token was obtained. Check offline_access and try again.");
    return false;
  }
  const current = await readFile(file, "utf8");
  const latest = parseEnv(current);
  const matches = [...current.matchAll(tokenLine)].length;
  if (latest.OUTLOOK_CLIENT_ID !== clientId || latest.OUTLOOK_SENDER_EMAIL !== sender ||
      latest.OUTLOOK_REFRESH_TOKEN !== env.OUTLOOK_REFRESH_TOKEN || matches > 1) {
    console.error("The Outlook settings changed or contain duplicate token entries. Check the file and try again.");
    return false;
  }
  const updated = matches === 1 ?
    current.replace(tokenLine, (_, key) => `${key}'${token}'`) :
    `${current.trimEnd()}\nOUTLOOK_REFRESH_TOKEN='${token}'\n`;
  if (parseEnv(updated).OUTLOOK_REFRESH_TOKEN !== token) return false;
  const temporary = `${file}.outlook.tmp`;
  await writeFile(temporary, updated, { flag: "wx", mode: 0o600 });
  try {
    await rename(temporary, file);
  } finally {
    await unlink(temporary).catch(() => {});
  }
  console.log(`Outlook authorization saved to ${file}. Restart the auth API to load it.`);
  return true;
}

try {
  if (!await main()) process.exitCode = 1;
} catch {
  console.error("Outlook setup failed. Check your local environment file, network, and app registration.");
  process.exitCode = 1;
}
