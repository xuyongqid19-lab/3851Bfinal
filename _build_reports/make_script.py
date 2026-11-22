# -*- coding: utf-8 -*-
"""Build XUYONGQI's 5-minute speech script (.docx)."""
from docx import Document
from docx.shared import Pt, RGBColor, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

BLUE = RGBColor(0x1F, 0x4E, 0x79)
DARK = RGBColor(0x26, 0x26, 0x26)
GRAY = RGBColor(0x5B, 0x6B, 0x7A)

def base(doc):
    st = doc.styles["Normal"]
    st.font.name = "Calibri"
    st.font.size = Pt(11)
    st.font.color.rgb = DARK
    st.paragraph_format.line_spacing = 1.2
    st.paragraph_format.space_after = Pt(8)
    rpr = st.element.get_or_add_rPr()
    rpr.get_or_add_rFonts().set(qn("w:eastAsia"), "Calibri")

def heading(doc, text, size=15, color=BLUE, space_before=10):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(space_before)
    p.paragraph_format.space_after = Pt(4)
    r = p.add_run(text)
    r.bold = True
    r.font.size = Pt(size)
    r.font.color.rgb = color
    return p

def para(doc, text, italic=False, color=None, bold=False, justify=True):
    p = doc.add_paragraph()
    if justify:
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    r = p.add_run(text)
    r.italic = italic
    r.bold = bold
    if color:
        r.font.color.rgb = color
    return p

def cue(doc, text):
    p = doc.add_paragraph()
    r = p.add_run(text)
    r.font.size = Pt(10.5)
    r.font.color.rgb = GRAY
    r.italic = True
    return p

doc = Document()
base(doc)

# ---- title ----
p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("Global Village — Group Presentation Speech Script")
r.bold = True; r.font.size = Pt(18); r.font.color.rgb = BLUE
p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("Speaker: XUYONGQI — Chat Module (4 slides, ~5 minutes total)")
r.bold = True; r.font.size = Pt(13)
p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run("Slides 7–10 of 21 · Speaking pace ≈ 130–140 words per minute · "
              "Cue words in grey are for your reference only — do not read "
              "them aloud.")
r.font.size = Pt(10.5); r.font.color.rgb = GRAY; r.italic = True

# ---- how to use ----
heading(doc, "How to use this script", 14)
para(doc, "Each section below matches one slide. The time in brackets is "
     "your target for that slide. The script is written at a natural "
     "speaking pace: if you finish a section early, slow down rather than "
     "adding content. Remember the course rules: camera on, and identify "
     "yourself by name the first time you speak — the script does this for "
     "you in the opening line. You do not need to memorise it word for "
     "word; keep the bolded key terms and the flow, and speak naturally.")
cue(doc, "提示：每个小节对应一页幻灯片。括号内时间为该页的目标时长。脚本按自然语速撰写，"
         "不需要逐字背诵——保住加粗关键词和顺序即可。开讲时记得先自报姓名（脚本第一句已包含）。")

# ---- Slide 7 ----
heading(doc, "Slide 7 — Chat: The Social Loop  [~75 seconds]", 14)
cue(doc, "提示要点：自报姓名 → 搜索加好友（邮箱/用户名/姓名）→ 铃铛角标通知 → "
         "接受后进入会话列表 → 文字+语音消息存入PostgreSQL。")
para(doc, "Thank you, Wangzuzan. My name is Xuyongqi, and I own the chat "
     "module — the main page and every sub-page you are about to see.")
para(doc, "Before two users can chat, they must become friends. The "
     "add-friend page searches by email, username or full name through the "
     "authentication service — so one search box covers every way you "
     "might know a person. Sending a request is one tap; the other user "
     "sees a live red badge on the bell icon of the home page, and can "
     "accept or decline. Once accepted, the conversation appears in the "
     "chat list — the app's main tab — with unread state tracked per user.")
para(doc, "Behind the scenes, the friend relationship, the request "
     "lifecycle and every message are persisted in the chat service's own "
     "PostgreSQL database. The chat detail page supports text and voice "
     "messages — you hold a button to record, and the clip is stored and "
     "replayed on both sides.")

# ---- Slide 8 ----
heading(doc, "Slide 8 — Chat: Group Governance  [~65 seconds]", 14)
cue(doc, "提示要点：群主（金色徽章）任命管理员（蓝色）→ 管理员可禁言/移除普通成员"
         "→ 被禁言者看到明确的红色提示而非消息被静默丢弃 → 移除后可再邀请回来。")
para(doc, "Group chats follow a real-world governance model rather than a "
     "free-for-all. The member who creates a group is its Owner — shown "
     "with a gold badge. Owners appoint administrators, shown in blue, and "
     "owners themselves cannot be muted or removed by anyone. "
     "Administrators can mute or remove ordinary members, but they cannot "
     "touch other admins or the owner.")
para(doc, "When a muted member opens the input bar, they see an explicit "
     "red restriction explaining they are muted — we deliberately show "
     "the rule instead of silently dropping their messages, because silent "
     "failure looks like a bug and breeds mistrust. Mutes can be lifted "
     "anytime; a removed member immediately loses access to history and "
     "calls, but can be invited back by the owner.")

# ---- Slide 9 ----
heading(doc, "Slide 9 — Chat: Real-Time Calls over WebRTC  [~95 seconds]",
        14)
cue(doc, "提示要点：这是技术含量最高的一页，语速放慢。1对1来电全屏接听/拒绝 → "
         "群通话全连接mesh（每对成员一条P2P连接，Google STUN）→ 信令走带JWT鉴权的"
         "WebSocket、心跳、1–30秒指数退避重连 → 迟到者看到'ongoing call'横幅可中途"
         "加入 → 静音/摄像头是track级操作无需重新协商。")
para(doc, "Calls are where this project went deepest technically. We "
     "implemented voice and video calling with WebRTC — real peer-to-peer "
     "media that never routes through our servers. The plumbing: the chat "
     "service exposes an authenticated WebSocket; every offer, answer and "
     "ICE candidate travels through it, gated by the same login token as "
     "everything else. The connection has a heartbeat and reconnects with "
     "exponential backoff from one to thirty seconds, so a flaky network "
     "degrades gracefully instead of dropping calls.")
para(doc, "One-to-one calls ring full-screen with accept and decline, a "
     "pulse animation and a running timer. Group calls use a full mesh: "
     "every participant holds one direct peer connection to every other "
     "participant, using Google's public STUN servers. Any member can "
     "start the call; online members get the full-screen invitation; and "
     "if you open the chat while a call is already running, you see this "
     "banner — \u201congoing call, tap to join\u201d — and join mid-call. Inside the "
     "call, mute and camera toggles are track-level, so they propagate "
     "instantly without renegotiation, and leaving tears down only your "
     "connections while the call continues.")

# ---- Slide 10 ----
heading(doc, "Slide 10 — Chat: AI Assistant & Verification  "
     "[~65 seconds]", 14)
cue(doc, "提示要点：AI助手经后端代理到GLM模型、历史存服务端、密钥只在服务器、"
         "界面明确标注为AI → 会话状态与存储有自动化测试（在105项套件内）→ "
         "三个浏览器窗口同时验证群通话 → 一句话总结本模块 → 交棒给Yinghaozhe。")
para(doc, "Finally, two things that round the module out. First, the AI "
     "assistant tab: conversations are proxied through our backend to a "
     "hosted GLM model, history is stored server-side, and the API key "
     "exists only on the server — it never ships in the client build. The "
     "feature is labelled as an AI assistant in the interface, because "
     "hiding what is automated would be misleading.")
para(doc, "Second, engineering discipline: the module's session-state and "
     "storage logic are covered by automated test suites that run inside "
     "the project's 105-test Flutter suite, and the whole flow was "
     "verified in three browser windows simultaneously with seeded demo "
     "accounts.")
para(doc, "In summary: friends, messaging, governed groups, peer-to-peer "
     "calls and an honest AI assistant — one module, one owner, fully "
     "delivered and tested. Next, Yinghaozhe will show the community "
     "module.")

# ---- delivery tips ----
heading(doc, "Delivery checklist for the recording", 14)
for tip in [
    "Camera on for your whole segment — the marking guide gives zero if "
    "any presenter's face is not visible.",
    "Say your name in your first sentence (the script does this) — every "
    "speaker must identify themselves.",
    "Do not read the slides aloud — the script gives you sentences that "
    "add to what is on screen, not repeat it.",
    "If you use the demo live, keep it to the group-call slide; otherwise "
    "talk over the diagrams.",
    "Practice once with a timer: your four sections should land near 75 + "
    "65 + 95 + 65 seconds; if you are over, trim Slide 8 first.",
]:
    p = doc.add_paragraph()
    r = p.add_run("• " + tip)
    r.font.size = Pt(11)
cue(doc, "提示：全程开摄像头；第一句自报姓名（脚本已含）；不要照读幻灯片；建议至少"
         "计时排练一次——超时先压缩第8页的内容。")

out = r"PPT\XUYONGQI_Speech_Script.docx"
doc.save(out)
print("Saved:", out)
