import { createServer } from "node:http";
import cors from "cors";
import express from "express";
import pg from "pg";
import { WebSocketServer, WebSocket } from "ws";

import "./load-env.js";

const { Pool } = pg;

const port = Number(process.env.PORT || 3004);
const databaseUrl =
  process.env.DATABASE_URL ||
  "postgres://global_village_chat:global_village_chat@localhost:5435/global_village_chat";
const authMeUrl =
  process.env.AUTH_API_ME_URL || "http://localhost:3002/auth/me";

// AI assistant (any OpenAI-compatible /chat/completions endpoint).
// Free default: Zhipu GLM glm-4-flash — get a key at https://open.bigmodel.cn
const aiApiKey = clean(process.env.AI_API_KEY);
const aiApiBaseUrl = (
  process.env.AI_API_BASE_URL || "https://open.bigmodel.cn/api/paas/v4"
).replace(/\/+$/, "");
const aiModel = process.env.AI_MODEL || "glm-4-flash";
const AI_CONTEXT_MESSAGES = 20;
const AI_SYSTEM_PROMPT = [
  "You are the Global Village AI Assistant inside a friendly community chat app.",
  "Always answer in the same language the user writes in.",
  "Be warm, concise and helpful. If a question is ambiguous, ask a short clarifying question.",
].join(" ");

const pool = new Pool({ connectionString: databaseUrl });
const app = express();

app.use(cors());
app.use(express.json({ limit: "5mb" }));

function clean(value) {
  return typeof value === "string" ? value.trim() : "";
}

async function verifyToken(header) {
  if (!header || !/^Bearer \S+$/.test(header)) {
    return null;
  }
  let response;
  try {
    response = await fetch(authMeUrl, {
      headers: { Authorization: header },
      signal: AbortSignal.timeout(8000),
    });
  } catch (_) {
    return null;
  }
  if (!response.ok) return null;
  let payload;
  try {
    payload = await response.json();
  } catch (_) {
    return null;
  }
  const user = payload?.user;
  if (!user || typeof user.id !== "string" || !user.id) return null;
  return user;
}

async function requireAuth(req, res, next) {
  const user = await verifyToken(req.headers.authorization || "");
  if (!user) {
    res.status(401).json({ error: "Please sign in to use chat." });
    return;
  }
  req.user = user;
  next();
}

function chatUserRow(row) {
  return {
    id: row.user_id,
    fullName: row.full_name,
    username: row.username,
    email: row.email,
    googlePhotoUrl: row.google_photo_url,
    interest: row.interest,
    authProvider: row.auth_provider,
  };
}

async function upsertChatUser(user) {
  await pool.query(
    `INSERT INTO chat_users (user_id, full_name, username, email, google_photo_url, interest, auth_provider, updated_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,now())
     ON CONFLICT (user_id)
     DO UPDATE SET full_name = $2, username = $3, email = $4,
       google_photo_url = $5, interest = $6, auth_provider = $7, updated_at = now()`,
    [
      user.id,
      clean(user.fullName),
      clean(user.username) || null,
      clean(user.email) || null,
      clean(user.googlePhotoUrl) || null,
      clean(user.interest) || null,
      clean(user.authProvider) || "local",
    ],
  );
}

async function findFriendship(a, b) {
  const result = await pool.query(
    `SELECT * FROM friendships
     WHERE (requester_id = $1 AND addressee_id = $2)
        OR (requester_id = $2 AND addressee_id = $1)
     LIMIT 1`,
    [a, b],
  );
  return result.rows[0] || null;
}

async function areFriends(a, b) {
  const result = await pool.query(
    `SELECT 1 FROM friendships
     WHERE status = 'accepted'
       AND ((requester_id = $1 AND addressee_id = $2)
         OR (requester_id = $2 AND addressee_id = $1))
     LIMIT 1`,
    [a, b],
  );
  return result.rows.length > 0;
}

function messageJson(row) {
  return {
    id: row.id,
    senderId: row.sender_id,
    receiverId: row.receiver_id,
    contentType: row.content_type,
    text: row.text,
    voiceData: row.voice_data,
    voiceMimeType: row.voice_mime_type,
    voiceDuration: row.voice_duration,
    readAt: row.read_at,
    createdAt: row.created_at,
  };
}

function groupMessageJson(row) {
  return {
    id: row.id,
    groupId: row.group_id,
    senderId: row.sender_id,
    senderName: row.sender_name,
    contentType: row.content_type,
    text: row.text,
    voiceData: row.voice_data,
    voiceMimeType: row.voice_mime_type,
    voiceDuration: row.voice_duration,
    createdAt: row.created_at,
  };
}

async function isGroupMember(groupId, userId) {
  if (!groupId || !userId) return false;
  const result = await pool.query(
    `SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2 LIMIT 1`,
    [groupId, userId],
  );
  return result.rows.length > 0;
}

const ROLE_RANK = { owner: 3, admin: 2, member: 1 };

async function groupMemberRow(groupId, userId) {
  if (!groupId || !userId) return null;
  const result = await pool.query(
    `SELECT group_id, user_id, role, is_muted, joined_at
     FROM group_members WHERE group_id = $1 AND user_id = $2 LIMIT 1`,
    [groupId, userId],
  );
  return result.rows[0] || null;
}

async function groupRoleOf(groupId, userId) {
  const row = await groupMemberRow(groupId, userId);
  return row ? row.role : null;
}

function parseMessageBody(body) {
  const text = clean(body.text).slice(0, 2000);
  const isLocation = body.isLocation === true;
  const isVoice = body.isVoice === true;
  const voiceData = isVoice ? (body.voiceData || "") : null;
  const voiceMimeType = isVoice ? clean(body.voiceMimeType) : null;
  const voiceDuration = isVoice ? Number(body.voiceDuration) || 0 : 0;
  return { text, isLocation, isVoice, voiceData, voiceMimeType, voiceDuration };
}

app.get("/health", async (_req, res, next) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true, service: "global-village-chat-api" });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/friends/requests", requireAuth, async (req, res, next) => {
  try {
    const me = req.user;
    const target = {
      id: clean(req.body.userId),
      fullName: clean(req.body.fullName),
      username: clean(req.body.username),
      email: clean(req.body.email),
      googlePhotoUrl: clean(req.body.googlePhotoUrl),
      interest: clean(req.body.interest),
      authProvider: clean(req.body.authProvider),
    };
    const message = clean(req.body.message).slice(0, 200);
    if (!target.id || target.id === me.id) {
      res.status(400).json({ error: "A valid target user is required." });
      return;
    }

    await upsertChatUser(me);
    await upsertChatUser(target);

    const existing = await findFriendship(me.id, target.id);
    if (existing) {
      if (existing.status === "accepted") {
        res.json({ status: "accepted" });
        return;
      }
      if (existing.requester_id === target.id) {
        await pool.query(
          `UPDATE friendships SET status = 'accepted', updated_at = now() WHERE id = $1`,
          [existing.id],
        );
        res.json({ status: "accepted" });
        return;
      }
      await pool.query(
        `UPDATE friendships SET message = $2, updated_at = now() WHERE id = $1`,
        [existing.id, message || existing.message],
      );
      res.json({ status: "pending" });
      return;
    }

    await pool.query(
      `INSERT INTO friendships (requester_id, addressee_id, status, message)
       VALUES ($1, $2, 'pending', $3)`,
      [me.id, target.id, message || null],
    );
    res.status(201).json({ status: "pending" });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/friends/accepts", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const requester = clean(req.body.userId);
    if (!requester) {
      res.status(400).json({ error: "A valid user id is required." });
      return;
    }
    const result = await pool.query(
      `UPDATE friendships
       SET status = 'accepted', updated_at = now()
       WHERE requester_id = $1 AND addressee_id = $2 AND status = 'pending'
       RETURNING id`,
      [requester, me],
    );
    if (result.rows.length === 0) {
      res.status(404).json({ error: "No pending friend request from this user." });
      return;
    }
    res.json({ status: "accepted" });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/friends/declines", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const requester = clean(req.body.userId);
    if (!requester) {
      res.status(400).json({ error: "A valid user id is required." });
      return;
    }
    const result = await pool.query(
      `DELETE FROM friendships
       WHERE requester_id = $1 AND addressee_id = $2 AND status = 'pending'
       RETURNING id`,
      [requester, me],
    );
    if (result.rows.length === 0) {
      res.status(404).json({ error: "No pending friend request from this user." });
      return;
    }
    res.json({ status: "declined" });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/friends/removals", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const other = clean(req.body.userId);
    if (!other || other === me) {
      res.status(400).json({ error: "A valid user id is required." });
      return;
    }
    const result = await pool.query(
      `DELETE FROM friendships
       WHERE (requester_id = $1 AND addressee_id = $2)
          OR (requester_id = $2 AND addressee_id = $1)
       RETURNING id, status`,
      [me, other],
    );
    if (result.rows.length === 0) {
      res.status(404).json({ error: "This user is not your friend." });
      return;
    }
    res.json({ status: "removed" });
  } catch (error) {
    next(error);
  }
});

app.get("/chat/friends", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const friends = await pool.query(
      `SELECT u.*, f.status
       FROM friendships f
       JOIN chat_users u
         ON u.user_id = CASE WHEN f.requester_id = $1 THEN f.addressee_id ELSE f.requester_id END
       WHERE f.status = 'accepted' AND (f.requester_id = $1 OR f.addressee_id = $1)
       ORDER BY u.full_name`,
      [me],
    );
    const incoming = await pool.query(
      `SELECT u.*, f.message, f.created_at
       FROM friendships f
       JOIN chat_users u ON u.user_id = f.requester_id
       WHERE f.status = 'pending' AND f.addressee_id = $1
       ORDER BY f.created_at DESC`,
      [me],
    );
    const outgoing = await pool.query(
      `SELECT u.*, f.message, f.created_at
       FROM friendships f
       JOIN chat_users u ON u.user_id = f.addressee_id
       WHERE f.status = 'pending' AND f.requester_id = $1
       ORDER BY f.created_at DESC`,
      [me],
    );
    res.json({
      friends: friends.rows.map(chatUserRow),
      incoming: incoming.rows.map((r) => ({
        ...chatUserRow(r),
        message: r.message,
        createdAt: r.created_at,
      })),
      outgoing: outgoing.rows.map((r) => ({
        ...chatUserRow(r),
        message: r.message,
        createdAt: r.created_at,
      })),
    });
  } catch (error) {
    next(error);
  }
});

// ---------------------------------------------------------------------------
// AI assistant chat. History lives in ai_messages; replies are generated by
// an OpenAI-compatible chat completions API and streamed to the client as
// Server-Sent Events:
//   data: {"userMessage":{...}}          echo of the stored user message
//   data: {"delta":"partial text"}       streamed reply fragment
//   data: {"done":true,"message":{...}}  final stored assistant message
//   data: {"error":"..."}                failure (nothing stored)
// ---------------------------------------------------------------------------

async function ensureAiTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS ai_messages (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL,
      role text NOT NULL CHECK (role IN ('user', 'assistant')),
      content text NOT NULL DEFAULT '',
      created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_ai_messages_user
      ON ai_messages (user_id, created_at);
  `);
}

function aiMessageJson(row) {
  return {
    id: row.id,
    role: row.role,
    content: row.content,
    createdAt: row.created_at,
  };
}

app.get("/chat/ai/messages", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const limit = Math.min(Math.max(Number(req.query.limit) || 200, 1), 500);
    const result = await pool.query(
      `SELECT * FROM (
         SELECT id, user_id, role, content, created_at FROM ai_messages
         WHERE user_id = $1
         ORDER BY created_at DESC LIMIT $2
       ) recent
       ORDER BY created_at ASC`,
      [me, limit],
    );
    res.json({
      enabled: Boolean(aiApiKey),
      messages: result.rows.map(aiMessageJson),
    });
  } catch (error) {
    next(error);
  }
});

app.delete("/chat/ai/messages", requireAuth, async (req, res, next) => {
  try {
    await pool.query(`DELETE FROM ai_messages WHERE user_id = $1`, [
      req.user.id,
    ]);
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/ai/messages", requireAuth, async (req, res, next) => {
  const me = req.user.id;
  const text = clean(req.body.text).slice(0, 4000);
  if (!text) {
    res.status(400).json({ error: "Message text is required." });
    return;
  }
  if (!aiApiKey) {
    res.status(503).json({
      error:
        "AI is not configured. Set AI_API_KEY on the chat server " +
        "(a free key from https://open.bigmodel.cn works with the default glm-4-flash model).",
    });
    return;
  }
  try {
    const stored = await pool.query(
      `INSERT INTO ai_messages (user_id, role, content)
       VALUES ($1, 'user', $2) RETURNING id, user_id, role, content, created_at`,
      [me, text],
    );
    const history = await pool.query(
      `SELECT role, content FROM (
         SELECT role, content, created_at FROM ai_messages
         WHERE user_id = $1
         ORDER BY created_at DESC LIMIT $2
       ) recent
       ORDER BY created_at ASC`,
      [me, AI_CONTEXT_MESSAGES],
    );
    const messages = [
      { role: "system", content: AI_SYSTEM_PROMPT },
      ...history.rows.map((r) => ({ role: r.role, content: r.content })),
    ];

    res.writeHead(200, {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    });
    const send = (obj) => {
      try {
        res.write(`data: ${JSON.stringify(obj)}\n\n`);
      } catch (_) {}
    };

    send({ userMessage: aiMessageJson(stored.rows[0]) });

    const abort = new AbortController();
    req.on("close", () => abort.abort());

    let full = "";
    let sawDelta = false;
    try {
      const upstream = await fetch(`${aiApiBaseUrl}/chat/completions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${aiApiKey}`,
        },
        body: JSON.stringify({ model: aiModel, messages, stream: true }),
        signal: abort.signal,
      });
      if (!upstream.ok || !upstream.body) {
        let detail = "";
        try {
          detail = (await upstream.text()).slice(0, 300);
        } catch (_) {}
        send({
          error: `AI service error (${upstream.status}).${detail ? " " + detail : ""}`,
        });
        res.end();
        return;
      }
      const decoder = new TextDecoder();
      let buffer = "";
      for await (const chunk of upstream.body) {
        buffer += decoder.decode(chunk, { stream: true });
        let newlineAt;
        while ((newlineAt = buffer.indexOf("\n")) >= 0) {
          const line = buffer.slice(0, newlineAt).trim();
          buffer = buffer.slice(newlineAt + 1);
          if (!line.startsWith("data:")) continue;
          const payload = line.slice(5).trim();
          if (!payload || payload === "[DONE]") continue;
          let parsed;
          try {
            parsed = JSON.parse(payload);
          } catch (_) {
            continue;
          }
          const delta = parsed?.choices?.[0]?.delta?.content;
          if (typeof delta === "string" && delta) {
            sawDelta = true;
            full += delta;
            send({ delta });
          }
        }
      }
      if (!sawDelta) {
        send({
          error: "The AI service returned an empty response. Please try again.",
        });
        res.end();
        return;
      }
      const saved = await pool.query(
        `INSERT INTO ai_messages (user_id, role, content)
         VALUES ($1, 'assistant', $2)
         RETURNING id, user_id, role, content, created_at`,
        [me, full],
      );
      send({ done: true, message: aiMessageJson(saved.rows[0]) });
    } catch (error) {
      if (abort.signal.aborted) {
        res.end();
        return;
      }
      send({ error: "AI service failed. Please try again." });
    }
    res.end();
  } catch (error) {
    if (!res.headersSent) {
      next(error);
      return;
    }
    try {
      res.write(`data: ${JSON.stringify({ error: "Server error during AI reply." })}\n\n`);
      res.end();
    } catch (_) {}
  }
});

app.get("/chat/conversations", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const result = await pool.query(
      `SELECT u.user_id, u.full_name, u.username, u.email,
              u.google_photo_url, u.interest, u.auth_provider,
              lm.id AS last_message_id, lm.content_type AS last_type,
              lm.text AS last_text, lm.created_at AS last_at,
              lm.sender_id AS last_sender,
              COALESCE(unread.cnt, 0) AS unread_count
       FROM friendships f
       JOIN chat_users u
         ON u.user_id = CASE WHEN f.requester_id = $1 THEN f.addressee_id ELSE f.requester_id END
       LEFT JOIN LATERAL (
         SELECT m.* FROM chat_messages m
         WHERE (m.sender_id = $1 AND m.receiver_id = u.user_id)
            OR (m.sender_id = u.user_id AND m.receiver_id = $1)
         ORDER BY m.created_at DESC LIMIT 1
       ) lm ON true
       LEFT JOIN LATERAL (
         SELECT count(*)::int AS cnt FROM chat_messages m
         WHERE m.sender_id = u.user_id AND m.receiver_id = $1 AND m.read_at IS NULL
       ) unread ON true
       WHERE f.status = 'accepted' AND (f.requester_id = $1 OR f.addressee_id = $1)
       ORDER BY lm.created_at DESC NULLS LAST, u.full_name`,
      [me],
    );
    const groups = await pool.query(
      `SELECT g.id AS group_id, g.name AS group_name, g.created_by,
              (SELECT count(*)::int FROM group_members gm WHERE gm.group_id = g.id) AS member_count,
              lm.id AS last_message_id, lm.content_type AS last_type,
              lm.text AS last_text, lm.created_at AS last_at,
              lm.sender_id AS last_sender,
              COALESCE(unread.cnt, 0) AS unread_count
       FROM group_members my
       JOIN group_chats g ON g.id = my.group_id
       LEFT JOIN LATERAL (
         SELECT m.* FROM group_messages m
         WHERE m.group_id = g.id
         ORDER BY m.created_at DESC LIMIT 1
       ) lm ON true
       LEFT JOIN LATERAL (
         SELECT count(*)::int AS cnt FROM group_messages m2
         WHERE m2.group_id = g.id
           AND m2.sender_id <> $1
           AND m2.created_at > my.last_read_at
       ) unread ON true
       WHERE my.user_id = $1
       ORDER BY lm.created_at DESC NULLS LAST, g.name`,
      [me],
    );
    res.json({
      conversations: result.rows.map((r) => ({
        user: chatUserRow(r),
        lastMessage: r.last_message_id
          ? {
              text: r.last_text,
              contentType: r.last_type,
              createdAt: r.last_at,
              fromMe: r.last_sender === me,
            }
          : null,
        unreadCount: r.unread_count,
      })),
      groups: groups.rows.map((r) => ({
        id: r.group_id,
        name: r.group_name,
        memberCount: r.member_count,
        createdBy: r.created_by,
        lastMessage: r.last_message_id
          ? {
              text: r.last_text,
              contentType: r.last_type,
              createdAt: r.last_at,
              fromMe: r.last_sender === me,
            }
          : null,
        unreadCount: r.unread_count,
      })),
    });
  } catch (error) {
    next(error);
  }
});

app.get("/chat/messages/:userId", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const other = clean(req.params.userId);
    if (!other || !(await areFriends(me, other))) {
      res.status(403).json({ error: "You can only chat with accepted friends." });
      return;
    }
    const result = await pool.query(
      `SELECT * FROM chat_messages
       WHERE (sender_id = $1 AND receiver_id = $2)
          OR (sender_id = $2 AND receiver_id = $1)
       ORDER BY created_at ASC
       LIMIT 500`,
      [me, other],
    );
    res.json({ messages: result.rows.map(messageJson) });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/messages", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const to = clean(req.body.toUserId);
    const text = clean(req.body.text).slice(0, 2000);
    const isLocation = req.body.isLocation === true;
    const isVoice = req.body.isVoice === true;
    const voiceData = isVoice ? (req.body.voiceData || "") : null;
    const voiceMimeType = isVoice ? clean(req.body.voiceMimeType) : null;
    const voiceDuration = isVoice ? Number(req.body.voiceDuration) || 0 : 0;

    if (!to || !(await areFriends(me, to))) {
      res.status(403).json({ error: "You can only chat with accepted friends." });
      return;
    }
    if (!isVoice && !text) {
      res.status(400).json({ error: "Message text is required." });
      return;
    }
    if (isVoice && (!voiceData || voiceDuration < 1)) {
      res.status(400).json({ error: "Voice message data is required." });
      return;
    }

    const contentType = isVoice ? "voice" : isLocation ? "location" : "text";
    const result = await pool.query(
      `INSERT INTO chat_messages (
         sender_id, receiver_id, content_type, text,
         voice_data, voice_mime_type, voice_duration
       ) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [me, to, contentType, isVoice ? "Voice message" : text, voiceData, voiceMimeType, voiceDuration],
    );
    res.status(201).json({ message: messageJson(result.rows[0]) });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/messages/:userId/read", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const other = clean(req.params.userId);
    await pool.query(
      `UPDATE chat_messages SET read_at = now()
       WHERE sender_id = $1 AND receiver_id = $2 AND read_at IS NULL`,
      [other, me],
    );
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/groups", requireAuth, async (req, res, next) => {
  try {
    const me = req.user;
    await upsertChatUser(me);
    const rawIds = Array.isArray(req.body.memberIds) ? req.body.memberIds : [];
    const memberIds = [
      ...new Set(
        rawIds.map((v) => clean(v)).filter(Boolean).filter((id) => id !== me.id),
      ),
    ];
    const name = clean(req.body.name).slice(0, 60);
    if (memberIds.length === 0) {
      res.status(400).json({ error: "Select at least one friend to start a group chat." });
      return;
    }
    for (const id of memberIds) {
      if (!(await areFriends(me.id, id))) {
        res.status(403).json({ error: "You can only add accepted friends to a group." });
        return;
      }
    }
    const created = await pool.query(
      `INSERT INTO group_chats (name, created_by) VALUES ($1, $2) RETURNING id, created_by`,
      [name || "", me.id],
    );
    const groupId = created.rows[0].id;
    const allMemberIds = [me.id, ...memberIds];
    await pool.query(
      `INSERT INTO group_members (group_id, user_id, role)
       SELECT $1, x, CASE WHEN x = $2 THEN 'owner' ELSE 'member' END
       FROM unnest($3::uuid[]) AS x`,
      [groupId, me.id, allMemberIds],
    );
    let groupName = name;
    if (!groupName) {
      const names = await pool.query(
        `SELECT u.full_name FROM group_members gm
         JOIN chat_users u ON u.user_id = gm.user_id
         WHERE gm.group_id = $1 AND gm.user_id <> $2
         ORDER BY u.full_name`,
        [groupId, me.id],
      );
      groupName = names.rows.map((r) => r.full_name).filter(Boolean).join(", ").slice(0, 60) || "Group chat";
      await pool.query(`UPDATE group_chats SET name = $1 WHERE id = $2`, [groupName, groupId]);
    }
    res.status(201).json({
      group: {
        id: groupId,
        name: groupName,
        memberCount: allMemberIds.length,
        createdBy: created.rows[0].created_by,
      },
    });
  } catch (error) {
    next(error);
  }
});

app.get("/chat/groups/:groupId", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const groupId = clean(req.params.groupId);
    const myRow = await groupMemberRow(groupId, me);
    if (!myRow) {
      res.status(403).json({ error: "You are not a member of this group." });
      return;
    }
    const group = await pool.query(
      `SELECT id, name, created_by FROM group_chats WHERE id = $1 LIMIT 1`,
      [groupId],
    );
    if (group.rows.length === 0) {
      res.status(404).json({ error: "Group not found." });
      return;
    }
    const members = await pool.query(
      `SELECT gm.user_id AS member_id, u.*, gm.role AS member_role,
              gm.is_muted AS member_muted, gm.joined_at
       FROM group_members gm
       LEFT JOIN chat_users u ON u.user_id = gm.user_id
       WHERE gm.group_id = $1
       ORDER BY gm.joined_at ASC`,
      [groupId],
    );
    res.json({
      group: {
        id: group.rows[0].id,
        name: group.rows[0].name,
        createdBy: group.rows[0].created_by,
        myRole: myRow.role,
        activeCall: activeCallSummary(groupId),
        members: members.rows.map((r) => ({
          ...chatUserRow({
            ...r,
            user_id: r.member_id,
            full_name: r.full_name || "Member",
          }),
          role: r.member_role,
          isMuted: r.member_muted === true,
        })),
      },
    });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/groups/:groupId/role", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const groupId = clean(req.params.groupId);
    const userId = clean(req.body.userId);
    const role = clean(req.body.role);
    if (role !== "admin" && role !== "member") {
      res.status(400).json({ error: "Role must be admin or member." });
      return;
    }
    const myRole = await groupRoleOf(groupId, me);
    if (myRole !== "owner") {
      res.status(403).json({ error: "Only the group owner can manage admins." });
      return;
    }
    const target = await groupMemberRow(groupId, userId);
    if (!target) {
      res.status(404).json({ error: "That user is not a group member." });
      return;
    }
    if (target.role === "owner") {
      res.status(403).json({ error: "The group owner role cannot be changed." });
      return;
    }
    await pool.query(
      `UPDATE group_members SET role = $3 WHERE group_id = $1 AND user_id = $2`,
      [groupId, userId, role],
    );
    res.json({ ok: true, role });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/groups/:groupId/mute", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const groupId = clean(req.params.groupId);
    const userId = clean(req.body.userId);
    const muted = req.body.muted === true;
    const myRole = await groupRoleOf(groupId, me);
    if (myRole !== "owner" && myRole !== "admin") {
      res.status(403).json({ error: "Only the owner or admins can mute members." });
      return;
    }
    const target = await groupMemberRow(groupId, userId);
    if (!target) {
      res.status(404).json({ error: "That user is not a group member." });
      return;
    }
    if (ROLE_RANK[target.role] >= ROLE_RANK[myRole]) {
      res.status(403).json({ error: "You cannot mute this member." });
      return;
    }
    await pool.query(
      `UPDATE group_members SET is_muted = $3 WHERE group_id = $1 AND user_id = $2`,
      [groupId, userId, muted],
    );
    res.json({ ok: true, muted });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/groups/:groupId/remove", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const groupId = clean(req.params.groupId);
    const userId = clean(req.body.userId);
    const myRole = await groupRoleOf(groupId, me);
    if (myRole !== "owner" && myRole !== "admin") {
      res.status(403).json({ error: "Only the owner or admins can remove members." });
      return;
    }
    if (userId === me) {
      res.status(400).json({ error: "Use Leave group to remove yourself." });
      return;
    }
    const target = await groupMemberRow(groupId, userId);
    if (!target) {
      res.status(404).json({ error: "That user is not a group member." });
      return;
    }
    if (ROLE_RANK[target.role] >= ROLE_RANK[myRole]) {
      res.status(403).json({ error: "You cannot remove this member." });
      return;
    }
    await pool.query(
      `DELETE FROM group_members WHERE group_id = $1 AND user_id = $2`,
      [groupId, userId],
    );
    removeFromGroupCallRoom(groupId, userId);
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/groups/:groupId/members", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const groupId = clean(req.params.groupId);
    if (!(await isGroupMember(groupId, me))) {
      res.status(403).json({ error: "You are not a member of this group." });
      return;
    }
    const rawIds = Array.isArray(req.body.userIds) ? req.body.userIds : [];
    const userIds = [
      ...new Set(
        rawIds.map((v) => clean(v)).filter(Boolean).filter((id) => id !== me.id),
      ),
    ];
    if (userIds.length === 0) {
      res.status(400).json({ error: "Select at least one friend to invite." });
      return;
    }
    for (const id of userIds) {
      if (!(await areFriends(me, id))) {
        res.status(403).json({ error: "You can only invite accepted friends to a group." });
        return;
      }
    }
    const existing = await pool.query(
      `SELECT user_id FROM group_members WHERE group_id = $1 AND user_id = ANY($2::uuid[])`,
      [groupId, userIds],
    );
    const existingIds = new Set(existing.rows.map((r) => r.user_id));
    const toAdd = userIds.filter((id) => !existingIds.has(id));
    let added = 0;
    if (toAdd.length > 0) {
      const inserted = await pool.query(
        `INSERT INTO group_members (group_id, user_id)
         SELECT $1, x FROM unnest($2::uuid[]) AS x
         ON CONFLICT (group_id, user_id) DO NOTHING
         RETURNING user_id`,
        [groupId, toAdd],
      );
      added = inserted.rows.length;
    }
    res.json({ added });
  } catch (error) {
    next(error);
  }
});

app.get("/chat/groups/:groupId/messages", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const groupId = clean(req.params.groupId);
    if (!(await isGroupMember(groupId, me))) {
      res.status(403).json({ error: "You are not a member of this group." });
      return;
    }
    const result = await pool.query(
      `SELECT m.*, u.full_name AS sender_name
       FROM group_messages m
       LEFT JOIN chat_users u ON u.user_id = m.sender_id
       WHERE m.group_id = $1
       ORDER BY m.created_at ASC
       LIMIT 500`,
      [groupId],
    );
    res.json({ messages: result.rows.map(groupMessageJson) });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/groups/:groupId/messages", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const groupId = clean(req.params.groupId);
    const { text, isLocation, isVoice, voiceData, voiceMimeType, voiceDuration } =
      parseMessageBody(req.body || {});
    const myRow = await groupMemberRow(groupId, me);
    if (!myRow) {
      res.status(403).json({ error: "You are not a member of this group." });
      return;
    }
    if (myRow.is_muted) {
      res.status(403).json({ error: "You are muted in this group." });
      return;
    }
    if (!isVoice && !text) {
      res.status(400).json({ error: "Message text is required." });
      return;
    }
    if (isVoice && (!voiceData || voiceDuration < 1)) {
      res.status(400).json({ error: "Voice message data is required." });
      return;
    }
    const contentType = isVoice ? "voice" : isLocation ? "location" : "text";
    const result = await pool.query(
      `INSERT INTO group_messages (
         group_id, sender_id, content_type, text,
         voice_data, voice_mime_type, voice_duration
       ) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [groupId, me, contentType, isVoice ? "Voice message" : text, voiceData, voiceMimeType, voiceDuration],
    );
    res.status(201).json({
      message: groupMessageJson({
        ...result.rows[0],
        sender_name: clean(req.user.fullName) || "Member",
      }),
    });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/groups/:groupId/read", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const groupId = clean(req.params.groupId);
    await pool.query(
      `UPDATE group_members SET last_read_at = now()
       WHERE group_id = $1 AND user_id = $2`,
      [groupId, me],
    );
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/groups/:groupId/leave", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const groupId = clean(req.params.groupId);
    if (!(await isGroupMember(groupId, me))) {
      res.status(403).json({ error: "You are not a member of this group." });
      return;
    }
    await pool.query(
      `DELETE FROM group_members WHERE group_id = $1 AND user_id = $2`,
      [groupId, me],
    );
    const remaining = await pool.query(
      `SELECT count(*)::int AS cnt FROM group_members WHERE group_id = $1`,
      [groupId],
    );
    if (remaining.rows[0].cnt === 0) {
      await pool.query(`DELETE FROM group_chats WHERE id = $1`, [groupId]);
    }
    removeFromGroupCallRoom(groupId, me);
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post("/chat/groups/:groupId/disband", requireAuth, async (req, res, next) => {
  try {
    const me = req.user.id;
    const groupId = clean(req.params.groupId);
    const group = await pool.query(
      `SELECT id, created_by FROM group_chats WHERE id = $1 LIMIT 1`,
      [groupId],
    );
    if (group.rows.length === 0) {
      res.status(404).json({ error: "Group not found." });
      return;
    }
    if (group.rows[0].created_by !== me) {
      res.status(403).json({ error: "Only the group creator can disband the group." });
      return;
    }
    await pool.query(`DELETE FROM group_chats WHERE id = $1`, [groupId]);
    destroyGroupCallRoom(groupId);
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ error: "Server error. Please try again." });
});

// ---------------------------------------------------------------------------
// WebRTC call signaling over WebSocket (/ws?token=<jwt>)
//
// Client -> server: { type: 'call', action, to, payload }
//   1:1  actions (to = peer userId): offer | answer | ice | decline | cancel | busy | end
//   group actions (to = groupId):    group-start | group-join | group-leave
//   mesh  actions (to = peer userId, payload.groupId): mesh-offer | mesh-answer | mesh-ice
// Server -> client: { type: 'call', action, from, fromName, fromPhoto, payload }
// Keepalive: client may send { type: 'ping' } and gets { type: 'pong' }.
// ---------------------------------------------------------------------------

const CALL_ACTIONS = new Set([
  "offer",
  "answer",
  "ice",
  "decline",
  "cancel",
  "busy",
  "end",
  "group-start",
  "group-join",
  "group-leave",
  "mesh-offer",
  "mesh-answer",
  "mesh-ice",
]);

const GROUP_ACTIONS = new Set(["group-start", "group-join", "group-leave"]);
const MESH_ACTIONS = new Set(["mesh-offer", "mesh-answer", "mesh-ice"]);

const httpServer = createServer(app);
const wss = new WebSocketServer({ noServer: true, maxPayload: 256 * 1024 });

// One active socket per user: a fresh connection replaces the old one.
const onlineSockets = new Map(); // userId -> WebSocket

// Group call rooms (full mesh): groupId -> { media, participants }
// participants: userId -> { socket, name, photo }
const groupCallRooms = new Map();
const roomOfUser = new Map(); // userId -> groupId

function nameFromUser(user) {
  return clean(user.fullName) || clean(user.username) || "Unknown";
}

function photoFromUser(user) {
  return clean(user.googlePhotoUrl) || null;
}

function rosterPayload(room) {
  return Array.from(room.participants.entries()).map(([id, p]) => ({
    id,
    name: p.name,
    photo: p.photo,
  }));
}

function activeCallSummary(groupId) {
  const room = groupCallRooms.get(groupId);
  if (!room) return null;
  return { media: room.media, participants: rosterPayload(room) };
}

function broadcastRoster(groupId) {
  const room = groupCallRooms.get(groupId);
  if (!room) return;
  const members = rosterPayload(room);
  for (const p of room.participants.values()) {
    if (p.socket.readyState === WebSocket.OPEN) {
      p.socket.send(
        JSON.stringify({
          type: "call",
          action: "group-roster",
          from: groupId,
          payload: { members },
        }),
      );
    }
  }
}

function addToGroupCallRoom(groupId, userId, ws) {
  const room = groupCallRooms.get(groupId);
  if (!room) return;
  room.participants.set(userId, {
    socket: ws,
    name: nameFromUser(ws.user),
    photo: photoFromUser(ws.user),
  });
  roomOfUser.set(userId, groupId);
}

function sendCallJson(ws, action, from, payload) {
  if (!ws || ws.readyState !== WebSocket.OPEN) return;
  ws.send(
    JSON.stringify({
      type: "call",
      action,
      from,
      payload: payload ?? null,
    }),
  );
}

function removeFromGroupCallRoom(groupId, userId) {
  if (roomOfUser.get(userId) !== groupId) return;
  roomOfUser.delete(userId);
  const room = groupCallRooms.get(groupId);
  if (!room) return;
  const departing = room.participants.get(userId);
  room.participants.delete(userId);
  if (departing && departing.socket.readyState === WebSocket.OPEN) {
    departing.socket.send(
      JSON.stringify({ type: "call", action: "group-gone", from: groupId }),
    );
  }
  if (room.participants.size === 0) {
    groupCallRooms.delete(groupId);
    return;
  }
  broadcastRoster(groupId);
}

function leaveIfSocketMatches(userId, socket) {
  const groupId = roomOfUser.get(userId);
  if (!groupId) return;
  const room = groupCallRooms.get(groupId);
  if (!room) {
    roomOfUser.delete(userId);
    return;
  }
  const participant = room.participants.get(userId);
  if (!participant || participant.socket !== socket) return;
  removeFromGroupCallRoom(groupId, userId);
}

function destroyGroupCallRoom(groupId) {
  const room = groupCallRooms.get(groupId);
  if (!room) return;
  for (const id of room.participants.keys()) {
    roomOfUser.delete(id);
  }
  for (const p of room.participants.values()) {
    sendCallJson(p.socket, "group-gone", groupId, null);
  }
  groupCallRooms.delete(groupId);
}

const heartbeat = setInterval(() => {
  for (const socket of wss.clients) {
    if (socket.isAlive === false) {
      socket.terminate();
      continue;
    }
    socket.isAlive = false;
    socket.ping();
  }
}, 30000);
wss.on("close", () => clearInterval(heartbeat));

httpServer.on("upgrade", async (req, socket, head) => {
  let url;
  try {
    url = new URL(req.url || "/", "http://localhost");
  } catch (_) {
    socket.destroy();
    return;
  }
  if (url.pathname !== "/ws") {
    socket.destroy();
    return;
  }
  const token = url.searchParams.get("token") || "";
  const user = await verifyToken(`Bearer ${token}`);
  if (!user) {
    socket.write("HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n");
    socket.destroy();
    return;
  }
  wss.handleUpgrade(req, socket, head, (ws) => {
    const previous = onlineSockets.get(user.id);
    if (previous && previous !== ws && previous.readyState === WebSocket.OPEN) {
      previous.send(JSON.stringify({ type: "replaced" }));
      previous.close(4000, "replaced");
    }
    onlineSockets.set(user.id, ws);
    ws.user = user;
    ws.isAlive = true;
    // Keep any group-call membership alive across reconnects of the same user.
    const roomId = roomOfUser.get(user.id);
    if (roomId) {
      const room = groupCallRooms.get(roomId);
      const participant = room?.participants.get(user.id);
      if (room && participant) {
        participant.socket = ws;
      }
    }
    wss.emit("connection", ws, req);
  });
});

wss.on("connection", (ws) => {
  ws.on("pong", () => {
    ws.isAlive = true;
  });

  ws.on("message", async (raw) => {
    let data;
    try {
      data = JSON.parse(raw.toString("utf8"));
    } catch (_) {
      return;
    }
    if (!data || typeof data !== "object") return;
    if (data.type === "ping") {
      ws.send(JSON.stringify({ type: "pong" }));
      return;
    }
    if (data.type !== "call") return;

    const action = clean(data.action);
    const to = clean(data.to);
    const me = ws.user;
    if (!CALL_ACTIONS.has(action)) return;
    if (!to) return;

    if (GROUP_ACTIONS.has(action)) {
      await handleGroupAction(ws, action, to, data.payload);
      return;
    }

    if (MESH_ACTIONS.has(action)) {
      handleMeshAction(ws, action, to, data.payload);
      return;
    }

    // 1:1 call signaling between friends.
    if (to === me.id) return;
    const target = onlineSockets.get(to);
    if (!target || target.readyState !== WebSocket.OPEN) {
      sendCallJson(ws, "offline", to, null);
      return;
    }
    if (action === "offer") {
      let friends = false;
      try {
        friends = await areFriends(me.id, to);
      } catch (_) {
        friends = false;
      }
      if (!friends) {
        sendCallJson(ws, "blocked", to, null);
        return;
      }
    }
    target.send(
      JSON.stringify({
        type: "call",
        action,
        from: me.id,
        fromName: nameFromUser(me),
        fromPhoto: photoFromUser(me),
        payload: data.payload ?? null,
      }),
    );
  });

  ws.on("close", () => {
    if (ws.user && onlineSockets.get(ws.user.id) === ws) {
      onlineSockets.delete(ws.user.id);
    }
    if (ws.user) {
      leaveIfSocketMatches(ws.user.id, ws);
    }
  });

  ws.on("error", () => {});
});

async function handleGroupAction(ws, action, groupId, payload) {
  const me = ws.user;

  if (action === "group-start") {
    const member = await groupMemberRow(groupId, me.id);
    if (!member) {
      sendCallJson(ws, "group-denied", groupId, null);
      return;
    }
    if (groupCallRooms.has(groupId)) {
      sendCallJson(ws, "group-busy", groupId, activeCallSummary(groupId));
      return;
    }
    const memberRows = await pool.query(
      `SELECT user_id FROM group_members WHERE group_id = $1`,
      [groupId],
    );
    const onlineOthers = memberRows.rows
      .map((r) => r.user_id)
      .filter((id) => id !== me.id)
      .filter((id) => {
        const socket = onlineSockets.get(id);
        return socket && socket.readyState === WebSocket.OPEN;
      });
    if (onlineOthers.length === 0) {
      sendCallJson(ws, "group-empty", groupId, null);
      return;
    }
    const group = await pool.query(
      `SELECT name FROM group_chats WHERE id = $1 LIMIT 1`,
      [groupId],
    );
    leaveIfSocketMatches(me.id, ws);
    groupCallRooms.set(groupId, {
      media: payload?.media === "video" ? "video" : "audio",
      participants: new Map(),
    });
    addToGroupCallRoom(groupId, me.id, ws);
    for (const id of onlineOthers) {
      const socket = onlineSockets.get(id);
      sendCallJson(socket, "group-incoming", groupId, {
        media: payload?.media === "video" ? "video" : "audio",
        callerId: me.id,
        callerName: nameFromUser(me),
        callerPhoto: photoFromUser(me),
        groupName: group.rows[0]?.name || "Group",
      });
    }
    sendCallJson(ws, "group-members", groupId, { members: [] });
    return;
  }

  if (action === "group-join") {
    const member = await groupMemberRow(groupId, me.id);
    if (!member) {
      sendCallJson(ws, "group-denied", groupId, null);
      return;
    }
    let room = groupCallRooms.get(groupId);
    if (!room) {
      sendCallJson(ws, "group-gone", groupId, null);
      return;
    }
    if (roomOfUser.get(me.id) === groupId) {
      // Re-join of the same session (e.g. after reconnect): refresh membership.
      room.participants.get(me.id).socket = ws;
    } else {
      leaveIfSocketMatches(me.id, ws);
      room = groupCallRooms.get(groupId);
      if (!room) {
        sendCallJson(ws, "group-gone", groupId, null);
        return;
      }
      addToGroupCallRoom(groupId, me.id, ws);
    }
    const others = rosterPayload(room).filter((m) => m.id !== me.id);
    sendCallJson(ws, "group-members", groupId, { members: others });
    broadcastRoster(groupId);
    return;
  }

  if (action === "group-leave") {
    removeFromGroupCallRoom(groupId, me.id);
    return;
  }
}

function handleMeshAction(ws, action, peerId, payload) {
  const me = ws.user;
  const groupId = clean(payload?.groupId);
  if (!groupId) return;
  if (peerId === me.id) return;
  if (roomOfUser.get(me.id) !== groupId) return;
  if (roomOfUser.get(peerId) !== groupId) return;
  const target = onlineSockets.get(peerId);
  if (!target || target.readyState !== WebSocket.OPEN) return;
  target.send(
    JSON.stringify({
      type: "call",
      action,
      from: me.id,
      fromName: nameFromUser(me),
      fromPhoto: photoFromUser(me),
      payload: payload ?? null,
    }),
  );
}

async function start() {
  try {
    await ensureAiTable();
  } catch (error) {
    console.error("Failed to ensure ai_messages table:", error);
  }
  httpServer.listen(port, process.env.HOST || "0.0.0.0", () => {
    console.log(`Global Village chat API listening on port ${port}`);
  });
}

start();
