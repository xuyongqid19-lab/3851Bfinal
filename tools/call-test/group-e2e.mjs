import { WebSocket } from "ws";

const [tokenA, tokenB, tokenC, idA, idB, idC] = process.argv.slice(2);
const base = "http://localhost:3004";

let failures = 0;
const check = (label, ok) => {
  console.log(`${ok ? "PASS" : "FAIL"} ${label}`);
  if (!ok) failures += 1;
};

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function api(token, method, path, body) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  try {
    json = await res.json();
  } catch (_) {}
  return { status: res.status, json };
}

function connect(token) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:3004/ws?token=${token}`);
    const messages = [];
    ws.on("message", (raw) => {
      try {
        messages.push(JSON.parse(raw.toString()));
      } catch (_) {}
    });
    ws.on("open", () => resolve({ ws, messages }));
    ws.on("error", reject);
    setTimeout(() => reject(new Error("ws connect timeout")), 8000);
  });
}

async function waitFor(list, predicate, label, ms = 8000, from = 0) {
  const start = Date.now();
  while (Date.now() - start < ms) {
    for (let i = from; i < list.length; i += 1) {
      if (predicate(list[i])) return list[i];
    }
    await wait(50);
  }
  throw new Error(`TIMEOUT waiting for ${label}`);
}

const call = (action) => (m) => m.type === "call" && m.action === action;
const notYet = (list, n) => list.length === n;

try {
  // Phase 0: A creates a group with B and C.
  const created = await api(tokenA, "POST", "/chat/groups", {
    name: "E2E Group",
    memberIds: [idB, idC],
  });
  check("A creates group with B and C", created.status === 201);
  const groupId = created.json?.group?.id;
  check("group id returned", !!groupId);

  // Phase 1: nobody else online -> group-empty.
  const A1 = await connect(tokenA);
  A1.ws.send(JSON.stringify({ type: "call", action: "group-start", to: groupId, payload: { media: "audio" } }));
  await waitFor(A1.messages, call("group-empty"), "group-empty when alone");
  check("group-start with no online members replies group-empty", true);

  // Phase 2: B and C online, A starts for real.
  const B = await connect(tokenB);
  const C = await connect(tokenC);
  await wait(300);
  A1.ws.send(JSON.stringify({ type: "call", action: "group-start", to: groupId, payload: { media: "audio" } }));
  const incomingB = await waitFor(B.messages, call("group-incoming"), "group-incoming at B");
  const incomingC = await waitFor(C.messages, call("group-incoming"), "group-incoming at C");
  check("B notified of group call", incomingB.from === groupId && incomingB.payload?.callerId === idA);
  check("C notified of group call", incomingC.from === groupId);
  check("group-incoming carries caller name", incomingB.payload?.callerName === "Call Tester A");
  const hostMembers = await waitFor(A1.messages, call("group-members"), "host group-members");
  check("host gets empty member list", Array.isArray(hostMembers.payload?.members) && hostMembers.payload.members.length === 0);

  // Phase 3: second start while ongoing -> group-busy.
  A1.ws.send(JSON.stringify({ type: "call", action: "group-start", to: groupId, payload: { media: "audio" } }));
  const busy = await waitFor(A1.messages, call("group-busy"), "group-busy");
  check("second group-start replies group-busy with active call", busy.payload?.participants?.length === 1);

  // Phase 4: B joins -> gets member list [A], roster broadcast.
  B.ws.send(JSON.stringify({ type: "call", action: "group-join", to: groupId, payload: { media: "audio" } }));
  const bMembers = await waitFor(B.messages, call("group-members"), "B group-members");
  check("B receives existing participants", bMembers.payload?.members?.length === 1 && bMembers.payload.members[0].id === idA);
  const rosterA1 = await waitFor(A1.messages, call("group-roster"), "roster at A after B joins");
  check("roster shows A and B", rosterA1.payload?.members?.length === 2);

  // Phase 5: C joins.
  C.ws.send(JSON.stringify({ type: "call", action: "group-join", to: groupId, payload: { media: "audio" } }));
  const cMembers = await waitFor(C.messages, call("group-members"), "C group-members");
  check("C receives A and B", cMembers.payload?.members?.length === 2);
  const rosterA2 = await waitFor(A1.messages, (m) => m.type === "call" && m.action === "group-roster" && m.payload?.members?.length === 3, "roster of 3 at A");
  check("roster grows to 3", rosterA2.payload.members.length === 3);

  // Phase 6: mesh signaling between room members.
  B.ws.send(JSON.stringify({ type: "call", action: "mesh-offer", to: idA, payload: { groupId, sdp: { type: "offer", sdp: "b>a" } } }));
  const meshOfferAtA = await waitFor(A1.messages, call("mesh-offer"), "mesh-offer at A");
  check("mesh-offer routed A<-B", meshOfferAtA.from === idB && meshOfferAtA.payload?.groupId === groupId);
  A1.ws.send(JSON.stringify({ type: "call", action: "mesh-answer", to: idB, payload: { groupId, sdp: { type: "answer", sdp: "a>b" } } }));
  const meshAnswerAtB = await waitFor(B.messages, call("mesh-answer"), "mesh-answer at B");
  check("mesh-answer routed B<-A", meshAnswerAtB.from === idA);
  A1.ws.send(JSON.stringify({ type: "call", action: "mesh-ice", to: idC, payload: { groupId, candidate: { candidate: "c" } } }));
  const meshIceAtC = await waitFor(C.messages, call("mesh-ice"), "mesh-ice at C");
  check("mesh-ice routed C<-A", meshIceAtC.from === idA);

  // Phase 7: B leaves -> gone + roster [A, C]; B's mesh no longer routed.
  const aCountBefore = A1.messages.length;
  B.ws.send(JSON.stringify({ type: "call", action: "group-leave", to: groupId, payload: null }));
  await waitFor(B.messages, call("group-gone"), "group-gone at B");
  check("leaver receives group-gone", true);
  const rosterAfterLeave = await waitFor(
    A1.messages,
    (m) =>
      m.type === "call" &&
      m.action === "group-roster" &&
      m.payload?.members?.length === 2 &&
      m.payload.members.some((x) => x.id === idC) &&
      !m.payload.members.some((x) => x.id === idB),
    "roster [A,C]",
  );
  check("roster after leave has A and C", rosterAfterLeave.payload.members.some((m) => m.id === idC));
  B.ws.send(JSON.stringify({ type: "call", action: "mesh-offer", to: idA, payload: { groupId, sdp: { type: "offer", sdp: "x" } } }));
  await wait(800);
  const strayMesh = A1.messages.slice(aCountBefore).find(call("mesh-offer"));
  check("mesh from non-room member is dropped", !strayMesh);

  // Phase 8: everyone leaves; room should be gone.
  C.ws.send(JSON.stringify({ type: "call", action: "group-leave", to: groupId, payload: null }));
  A1.ws.send(JSON.stringify({ type: "call", action: "group-leave", to: groupId, payload: null }));
  await wait(300);
  const cLenBeforeJoin = C.messages.length;
  C.ws.send(JSON.stringify({ type: "call", action: "group-join", to: groupId, payload: { media: "audio" } }));
  await waitFor(C.messages, call("group-gone"), "group-gone on join after room emptied", 8000, cLenBeforeJoin);
  check("empty room is destroyed", true);

  // Phase 9: REST roles / mute / remove.
  const promoteByB = await api(tokenB, "POST", `/chat/groups/${groupId}/role`, { userId: idB, role: "admin" });
  check("member cannot promote self", promoteByB.status === 403);
  const promoteB = await api(tokenA, "POST", `/chat/groups/${groupId}/role`, { userId: idB, role: "admin" });
  check("owner promotes B to admin", promoteB.status === 200);
  const infoAsB = await api(tokenB, "GET", `/chat/groups/${groupId}`);
  check("B sees own admin role", infoAsB.json?.group?.myRole === "admin");
  const infoAsA = await api(tokenA, "GET", `/chat/groups/${groupId}`);
  check("owner sees admin badge on B", infoAsA.json?.group?.members?.some((m) => m.id === idB && m.role === "admin"));
  const infoAsC = await api(tokenC, "GET", `/chat/groups/${groupId}`);
  check("member role visible", infoAsC.json?.group?.myRole === "member");

  const muteByC = await api(tokenC, "POST", `/chat/groups/${groupId}/mute`, { userId: idB, muted: true });
  check("member cannot mute admin", muteByC.status === 403);
  const muteC = await api(tokenB, "POST", `/chat/groups/${groupId}/mute`, { userId: idC, muted: true });
  check("admin mutes member", muteC.status === 200);
  const msgMuted = await api(tokenC, "POST", `/chat/groups/${groupId}/messages`, { text: "hello while muted" });
  check("muted member cannot send message", msgMuted.status === 403);
  const unmuteC = await api(tokenB, "POST", `/chat/groups/${groupId}/mute`, { userId: idC, muted: false });
  check("admin unmutes member", unmuteC.status === 200);
  const msgAfter = await api(tokenC, "POST", `/chat/groups/${groupId}/messages`, { text: "hello again" });
  check("unmuted member can send message", msgAfter.status === 201);

  const removeByC = await api(tokenC, "POST", `/chat/groups/${groupId}/remove`, { userId: idB });
  check("member cannot remove admin", removeByC.status === 403);
  const removeC = await api(tokenB, "POST", `/chat/groups/${groupId}/remove`, { userId: idC });
  check("admin removes member", removeC.status === 200);
  const infoAsCremoved = await api(tokenC, "GET", `/chat/groups/${groupId}`);
  check("removed member loses group access", infoAsCremoved.status === 403);

  C.ws.send(JSON.stringify({ type: "call", action: "group-join", to: groupId, payload: { media: "audio" } }));
  await waitFor(C.messages, call("group-denied"), "group-denied at removed C");
  check("removed member cannot join group call", true);

  const reinvite = await api(tokenA, "POST", `/chat/groups/${groupId}/members`, { userIds: [idC] });
  check("owner re-invites removed member", reinvite.status === 200 && reinvite.json?.added === 1);
  const demoteB = await api(tokenA, "POST", `/chat/groups/${groupId}/role`, { userId: idB, role: "member" });
  check("owner demotes admin back to member", demoteB.status === 200);

  // Phase 10: cleanup.
  const disband = await api(tokenA, "POST", `/chat/groups/${groupId}/disband`);
  check("owner disbands group", disband.status === 200);

  A1.ws.close();
  B.ws.close();
  C.ws.close();
} catch (error) {
  check(`scenario error: ${error.message}`, false);
}

process.exit(failures > 0 ? 1 : 0);
