import { WebSocket } from "ws";

const [tokenA, tokenB, tokenD, idA, idB, idD] = process.argv.slice(2);

const urlFor = (token) => `ws://localhost:3004/ws?token=${token}`;

function connect(token) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(urlFor(token));
    const messages = [];
    ws.on("message", (raw) => {
      try {
        messages.push(JSON.parse(raw.toString()));
      } catch (_) {}
    });
    ws.on("open", () => resolve({ ws, messages }));
    ws.on("error", reject);
    ws.on("close", (code) => resolve({ ws, messages, closed: code }));
    setTimeout(() => reject(new Error("ws connect timeout")), 8000);
  });
}

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitFor(list, predicate, label, ms = 8000) {
  const start = Date.now();
  while (Date.now() - start < ms) {
    const found = list.find(predicate);
    if (found) return found;
    await wait(50);
  }
  throw new Error(`TIMEOUT waiting for ${label}`);
}

let failures = 0;
const check = (label, ok) => {
  console.log(`${ok ? "PASS" : "FAIL"} ${label}`);
  if (!ok) failures += 1;
};

try {
  const A = await connect(tokenA);
  const B = await connect(tokenB);
  const D = await connect(tokenD);
  await wait(300);

  A.ws.send(
    JSON.stringify({
      type: "call",
      action: "offer",
      to: idB,
      payload: { media: "video", sdp: { type: "offer", sdp: "x" } },
    }),
  );
  const offerMsg = await waitFor(
    B.messages,
    (m) => m.type === "call" && m.action === "offer",
    "offer at B",
  );
  check("offer routed to B", offerMsg.from === idA);
  check("offer carries fromName", offerMsg.fromName === "Call Tester A");
  check("offer payload passthrough", offerMsg.payload?.media === "video");

  B.ws.send(
    JSON.stringify({
      type: "call",
      action: "answer",
      to: idA,
      payload: { sdp: { type: "answer", sdp: "y" } },
    }),
  );
  const answerMsg = await waitFor(
    A.messages,
    (m) => m.type === "call" && m.action === "answer",
    "answer at A",
  );
  check("answer routed to A", answerMsg.from === idB);

  A.ws.send(
    JSON.stringify({
      type: "call",
      action: "ice",
      to: idB,
      payload: { candidate: { candidate: "c" } },
    }),
  );
  const iceMsg = await waitFor(
    B.messages,
    (m) => m.type === "call" && m.action === "ice",
    "ice at B",
  );
  check("ice routed to B", !!iceMsg.payload?.candidate?.candidate);

  B.ws.send(JSON.stringify({ type: "call", action: "end", to: idA, payload: null }));
  await waitFor(
    A.messages,
    (m) => m.type === "call" && m.action === "end",
    "end at A",
  );
  check("end routed to A", true);

  A.ws.send(
    JSON.stringify({
      type: "call",
      action: "offer",
      to: "00000000-0000-4000-8000-000000000000",
      payload: {},
    }),
  );
  await waitFor(
    A.messages,
    (m) => m.type === "call" && m.action === "offline",
    "offline reply",
  );
  check("offer to offline user replies offline", true);

  A.ws.send(
    JSON.stringify({
      type: "call",
      action: "offer",
      to: idD,
      payload: { media: "audio" },
    }),
  );
  await waitFor(
    A.messages,
    (m) => m.type === "call" && m.action === "blocked",
    "blocked reply",
  );
  check("offer to non-friend is blocked", true);
  const dGotOffer = D.messages.some((m) => m.type === "call" && m.action === "offer");
  check("blocked offer never reaches non-friend", !dGotOffer);

  A.ws.send(JSON.stringify({ type: "ping" }));
  await waitFor(A.messages, (m) => m.type === "pong", "pong");
  check("ping/pong keepalive", true);

  const B2 = await connect(tokenB);
  await wait(300);
  const replacedMsg = await waitFor(
    B.messages,
    (m) => m.type === "replaced",
    "replaced notice",
  );
  check("second connection replaces first", !!replacedMsg);

  A.ws.close();
  B2.ws.close();
  D.ws.close();
} catch (error) {
  check(`scenario error: ${error.message}`, false);
}

try {
  await connect("invalid-token-value");
  check("bad token rejected", false);
} catch (_) {
  check("bad token rejected", true);
}

process.exit(failures > 0 ? 1 : 0);
