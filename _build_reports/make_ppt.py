# -*- coding: utf-8 -*-
"""GlobalVillage group presentation — 5 minutes PER MEMBER (total ~25 min).
21 slides: shared opening (WANGZUZAN), 3-4 deep-dive slides per module,
closing slot (HUANGZHIYONG)."""
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE, MSO_CONNECTOR
from pptx.oxml.ns import qn
import math

PRIMARY  = RGBColor(0x1F, 0x4E, 0x79)
SECOND   = RGBColor(0x2E, 0x9B, 0xD6)
LIGHT    = RGBColor(0xEA, 0xF2, 0xFA)
LIGHT2   = RGBColor(0xF7, 0xFA, 0xFD)
ACCENT   = RGBColor(0xE8, 0xA3, 0x3D)
DARK     = RGBColor(0x26, 0x26, 0x26)
GRAY     = RGBColor(0x5B, 0x6B, 0x7A)
WHITE    = RGBColor(0xFF, 0xFF, 0xFF)
GREEN    = RGBColor(0x2E, 0x9E, 0x5B)
RED      = RGBColor(0xC0, 0x50, 0x46)
LINEC    = RGBColor(0xC9, 0xDC, 0xEC)

SW, SH = Inches(13.333), Inches(7.5)
N_SLIDES = 21

prs = Presentation()
prs.slide_width = SW
prs.slide_height = SH
BLANK = prs.slide_layouts[6]

# ---------------- helpers ----------------

def add_slide():
    return prs.slides.add_slide(BLANK)

def no_shadow(shp):
    try:
        shp.shadow.inherit = False
    except Exception:
        pass

def rect(slide, x, y, w, h, fill=WHITE, line=None, line_w=None,
         rounded=True, radius=0.10):
    shp_type = (MSO_SHAPE.ROUNDED_RECTANGLE if rounded else MSO_SHAPE.RECTANGLE)
    shp = slide.shapes.add_shape(shp_type, x, y, w, h)
    if rounded:
        try:
            shp.adjustments[0] = radius
        except Exception:
            pass
    if fill is None:
        shp.fill.background()
    else:
        shp.fill.solid(); shp.fill.fore_color.rgb = fill
    if line is None:
        shp.line.fill.background()
    else:
        shp.line.color.rgb = line
        shp.line.width = line_w or Pt(1)
    no_shadow(shp)
    return shp

def txt(slide, x, y, w, h, lines, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP,
        wrap=True):
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame
    tf.word_wrap = wrap
    tf.vertical_anchor = anchor
    first = True
    for item in lines:
        text, opts = (item if isinstance(item, tuple) else (item, {}))
        p = tf.paragraphs[0] if first else tf.add_paragraph()
        first = False
        p.alignment = opts.get("align", align)
        p.space_before = Pt(opts.get("sb", 0))
        p.space_after = Pt(opts.get("sa", 4))
        run = p.add_run(); run.text = text
        f = run.font
        f.name = opts.get("font", "Calibri")
        f.size = Pt(opts.get("size", 16))
        f.bold = opts.get("bold", False)
        f.italic = opts.get("italic", False)
        f.color.rgb = opts.get("color", DARK)
    return tb

def shape_text(shp, lines, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE,
               m=0.06):
    tf = shp.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = Inches(m)
    tf.margin_top = tf.margin_bottom = Inches(0.03)
    first = True
    for item in lines:
        text, opts = (item if isinstance(item, tuple) else (item, {}))
        p = tf.paragraphs[0] if first else tf.add_paragraph()
        first = False
        p.alignment = opts.get("align", align)
        p.space_before = Pt(opts.get("sb", 0))
        p.space_after = Pt(opts.get("sa", 2))
        run = p.add_run(); run.text = text
        f = run.font
        f.name = "Calibri"
        f.size = Pt(opts.get("size", 13))
        f.bold = opts.get("bold", False)
        f.color.rgb = opts.get("color", DARK)

def arrow(slide, x1, y1, x2, y2, color=SECOND, w=2.0, head=True):
    conn = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, x1, y1, x2, y2)
    conn.line.color.rgb = color
    conn.line.width = Pt(w)
    if head:
        ln = conn.line._get_or_add_ln()
        tail = ln.makeelement(qn('a:tailEnd'),
                              {'type': 'triangle', 'w': 'med', 'len': 'med'})
        ln.append(tail)
    return conn

def slide_frame(s, title, idx, subtitle=None, owner=None, right_tag=None):
    rect(s, 0, 0, SW, Inches(0.95), fill=PRIMARY, rounded=False)
    txt(s, Inches(0.45), Inches(0.14), Inches(10.0), Inches(0.7),
        [(title, {"size": 27, "bold": True, "color": WHITE})],
        anchor=MSO_ANCHOR.MIDDLE)
    if owner:
        chip(s, Inches(10.55), Inches(0.24), Inches(2.55), Inches(0.47),
             f"Module owner: {owner}", fill=ACCENT, size=12)
    elif right_tag:
        chip(s, Inches(10.05), Inches(0.24), Inches(3.05), Inches(0.47),
             right_tag, fill=ACCENT, size=12)
    else:
        txt(s, Inches(10.9), Inches(0.22), Inches(2.2), Inches(0.5),
            [("COMP3851 · Group", {"size": 11,
                                   "color": RGBColor(0xBF, 0xD4, 0xE8),
                                   "align": PP_ALIGN.RIGHT})],
            anchor=MSO_ANCHOR.MIDDLE)
    if subtitle:
        txt(s, Inches(0.47), Inches(0.98), Inches(12.4), Inches(0.34),
            [(subtitle, {"size": 13.5, "color": GRAY, "italic": True})])
    rect(s, 0, Inches(7.18), SW, Pt(1.2), fill=RGBColor(0xD5, 0xE2, 0xEE),
         rounded=False)
    txt(s, Inches(0.45), Inches(7.22), Inches(9.0), Inches(0.26),
        [("Global Village — A Cross-Platform Community Application",
          {"size": 10, "color": GRAY})])
    txt(s, Inches(12.2), Inches(7.22), Inches(0.9), Inches(0.26),
        [(f"{idx} / {N_SLIDES}",
          {"size": 10, "color": GRAY, "align": PP_ALIGN.RIGHT})])

def notes(s, text):
    s.notes_slide.notes_text_frame.text = text

def card(s, x, y, w, h, title, body, fill=LIGHT, tcolor=PRIMARY, tsize=14,
         bsize=12.5, bar=SECOND):
    c = rect(s, x, y, w, h, fill=fill, line=LINEC, line_w=Pt(1))
    if bar:
        rect(s, x, y + Inches(0.06), Inches(0.07), h - Inches(0.12), fill=bar,
             rounded=False)
    lines = [(title, {"size": tsize, "bold": True, "color": tcolor,
                      "align": PP_ALIGN.LEFT})]
    if isinstance(body, str):
        body = [body]
    for b in body:
        lines.append((b, {"size": bsize, "color": DARK, "align": PP_ALIGN.LEFT,
                          "sa": 2}))
    shape_text(c, lines, align=PP_ALIGN.LEFT,
               anchor=MSO_ANCHOR.TOP, m=0.16)
    return c

def chip(s, x, y, w, h, text, fill=PRIMARY, color=WHITE, size=12, bold=True):
    c = rect(s, x, y, w, h, fill=fill, radius=0.5)
    shape_text(c, [(text, {"size": size, "bold": bold, "color": color})])
    return c

def band(s, x, y, w, h, text, fill=PRIMARY, size=13.5, color=WHITE):
    b = rect(s, x, y, w, h, fill=fill, radius=0.15)
    shape_text(b, [(text, {"size": size, "bold": True, "color": color})])
    return b

def steps_flow(s, x, y, w, h, steps, gap=0.26, hi=None):
    """Vertical step boxes with arrows between.
    x, y, w, h, gap are plain floats in INCHES."""
    yy = y
    for i, (t, d) in enumerate(steps):
        fill = PRIMARY if (hi is not None and i == hi) else LIGHT
        tcol = WHITE if (hi is not None and i == hi) else PRIMARY
        dcol = RGBColor(0xCF, 0xE2, 0xF2) if (hi is not None and i == hi) else GRAY
        b = rect(s, Inches(x), Inches(yy), Inches(w), Inches(h), fill=fill,
                 line=SECOND if (hi is None or i != hi) else PRIMARY,
                 line_w=Pt(1.2), radius=0.14)
        shape_text(b, [(t, {"size": 13.5, "bold": True, "color": tcol,
                            "sa": 0}),
                       (d, {"size": 10.5, "color": dcol})], m=0.05)
        if i < len(steps) - 1:
            arrow(s, Inches(x + w / 2), Inches(yy + h), Inches(x + w / 2),
                  Inches(yy + h + gap - 0.02), w=2.0)
        yy += h + gap
    return yy

# =====================================================================
# SLOT 1 — WANGZUZAN (~5:00): opening + architecture + authentication
# =====================================================================

# ---- Slide 1: title ----
s = add_slide()
rect(s, 0, 0, SW, SH, fill=WHITE, rounded=False)
rect(s, 0, 0, SW, Inches(2.6), fill=PRIMARY, rounded=False)
g = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(11.4), Inches(0.55),
                       Inches(1.45), Inches(1.45))
g.fill.background(); g.line.color.rgb = WHITE; g.line.width = Pt(2.25)
no_shadow(g)
for dy in (0.18, 0.55, 0.92):
    a = s.shapes.add_shape(MSO_SHAPE.ARC, Inches(11.72), Inches(0.55 + dy),
                           Inches(0.82), Inches(0.55))
    a.fill.background(); a.line.color.rgb = SECOND; a.line.width = Pt(1.5)
    no_shadow(a)
txt(s, Inches(0.7), Inches(0.42), Inches(10.4), Inches(2.0), [
    ("Global Village", {"size": 44, "bold": True, "color": WHITE, "sa": 6}),
    ("A Cross-Platform Community Application with Microservice Backends "
     "for Authentication, Chat, Community, Family and Profile",
     {"size": 17, "color": RGBColor(0xCF, 0xE2, 0xF2)}),
])
txt(s, Inches(0.7), Inches(2.85), Inches(12.0), Inches(0.4),
    [("COMP3851A/B — Work Integrated Learning · Group Presentation · "
      "November 2026 · 5 minutes per member",
      {"size": 15, "color": PRIMARY, "bold": True})])
team = [("WANGZUZAN", "Authentication"), ("XUYONGQI", "Chat"),
        ("YINGHAOZHE", "Community"), ("DAIZIHONG", "Family"),
        ("HUANGZHIYONG", "Profile")]
cw = Inches(2.38); gapx = Inches(0.14); x0 = Inches(0.7)
for i, (name, mod) in enumerate(team):
    x = x0 + i * (cw + gapx)
    c = rect(s, x, Inches(3.6), cw, Inches(1.5), fill=LIGHT, line=LINEC,
             line_w=Pt(1))
    shape_text(c, [
        (name, {"size": 15, "bold": True, "color": PRIMARY, "sa": 2}),
        (mod, {"size": 12.5, "color": GRAY}),
    ])
strip = ["Flutter Web + Android", "4 Docker microservices",
         "WebRTC voice & video", "Consent-based family tree"]
x0 = Inches(0.7); cw2 = Inches(2.98); gap2 = Inches(0.16)
for i, t in enumerate(strip):
    chip(s, x0 + i * (cw2 + gap2), Inches(5.6), cw2, Inches(0.52), t,
         fill=LIGHT, color=PRIMARY, size=13)
txt(s, Inches(0.7), Inches(6.45), Inches(12.0), Inches(0.5),
    [("One integrated, privacy-conscious platform — self-hosted, modular, "
      "and deployable from laptop to cloud.",
      {"size": 14, "color": GRAY, "italic": True})])
notes(s, "[~15s] Presenter: WANGZUZAN (opening).\n"
         "Greet the audience, introduce the five members and the one-line "
         "pitch: Global Village is a cross-platform community app built as "
         "four microservices, one per module. Explain the talk format: "
         "each member presents their own module for about five minutes.")

# ---- Slide 2: background ----
s = add_slide()
slide_frame(s, "Background & Motivation", 2)
card(s, Inches(0.45), Inches(1.25), Inches(4.1), Inches(3.4),
     "The problem", [
         "Social lives are fragmented across tools:",
         "• messaging in one app",
         "• community events in another",
         "• family coordination in a group chat",
         "Data sits with advertising-driven platforms; nothing serves "
         "community engagement and private family life together."],
     tsize=16)
card(s, Inches(4.75), Inches(1.25), Inches(4.1), Inches(1.6), "WeChat  [2]",
     ["Closed ecosystem — no self-hosting, no modular deployment, "
      "no consent-based family tree."], fill=LIGHT2, tsize=14)
card(s, Inches(4.75), Inches(3.05), Inches(4.1), Inches(1.6),
     "Facebook Groups  [3]",
     ["Advertising-driven data model; centrally operated media; "
      "no structured family coordination."], fill=LIGHT2, tsize=14)
card(s, Inches(9.05), Inches(1.25), Inches(3.85), Inches(3.4),
     "Global Village differs", [
         "• Self-hostable — runs locally or on your own Azure cloud",
         "• Modular — 4 independent microservices",
         "• Privacy-conscious — bcrypt + session invalidation, P2P "
         "WebRTC media, consent-based family tree",
         "7.5M+ Australians born overseas [1] — communities need one "
         "integrated, trustworthy platform."],
     tsize=15, bar=ACCENT)
band(s, Inches(0.45), Inches(5.0), Inches(12.45), Inches(1.55),
     "Motivation: one integrated, deployable product — built to industry "
     "standard (containerised, tested, secured, staged releases) — that a "
     "community can host and control itself.", size=15.5)
txt(s, Inches(0.45), Inches(6.75), Inches(12.4), Inches(0.3),
    [("References [1] ABS Cultural Diversity Census 2021 · [2] Tencent "
      "WeChat · [3] Meta Facebook Groups",
      {"size": 10.5, "color": GRAY})])
notes(s, "[~45s] Presenter: WANGZUZAN.\n"
         "Communities fragment their social lives across several apps; "
         "incumbents either cannot be self-hosted (WeChat) or monetise "
         "user data (Facebook Groups). Global Village: self-hostable, "
         "modular, privacy-conscious — and built to industry standard as a "
         "two-semester capstone.")

# ---- Slide 3: aims ----
s = add_slide()
slide_frame(s, "Project Aims — Two Semesters, Seven Aims", 3,
            subtitle="All core aims completed; Aim 7 delivered with ongoing "
                     "maintenance")
aims_l = [
    ("1", "Secure cross-platform app (Flutter web + Android)"),
    ("2", "Modular microservice backend (4 services, own DBs, Docker)"),
    ("3", "Real-time communication (friends, messages, WebRTC calls)"),
]
aims_r = [
    ("4", "Community engagement (activities, nearby people, map)"),
    ("5", "Family module with consent-based family tree"),
    ("6", "Profile management + interest matching"),
    ("7", "Deployable releases (demo, Azure TLS, Android APKs)"),
]
for col, x in ((aims_l, Inches(0.5)), (aims_r, Inches(6.75))):
    yy = Inches(1.75)
    for num, text in col:
        rect(s, x, yy, Inches(6.1), Inches(0.88), fill=LIGHT, line=LINEC,
             line_w=Pt(1))
        n = rect(s, x + Inches(0.12), yy + Inches(0.13), Inches(0.62),
                 Inches(0.62), fill=PRIMARY, radius=0.5)
        shape_text(n, [(num, {"size": 18, "bold": True, "color": WHITE})])
        txt(s, x + Inches(0.9), yy + Inches(0.1), Inches(4.35),
            Inches(0.68), [(text, {"size": 13.5})], anchor=MSO_ANCHOR.MIDDLE)
        ok = s.shapes.add_shape(MSO_SHAPE.OVAL, x + Inches(5.35),
                                yy + Inches(0.21), Inches(0.45), Inches(0.45))
        ok.fill.solid(); ok.fill.fore_color.rgb = GREEN
        ok.line.fill.background(); no_shadow(ok)
        shape_text(ok, [("✓", {"size": 14, "bold": True, "color": WHITE})])
        yy += Inches(1.02)
txt(s, Inches(0.5), Inches(6.35), Inches(6.0), Inches(0.4),
    [("Aims scaffold: platform → communication → community → family.",
      {"size": 12, "color": GRAY, "italic": True})])
txt(s, Inches(6.75), Inches(6.35), Inches(6.0), Inches(0.4),
    [("Aim 7: complete — the public demo URL is temporary, so maintenance "
      "continues.", {"size": 12, "color": GRAY, "italic": True})])
notes(s, "[~25s] Presenter: WANGZUZAN.\n"
         "Seven aims scaffolded over two semesters: platform first, then "
         "communication, community, family. All seven delivered — aims 1–6 "
         "fully complete, aim 7 complete with ongoing demo maintenance.")

# ---- Slide 4: architecture ----
s = add_slide()
slide_frame(s, "System Architecture", 4)
c1 = rect(s, Inches(0.8), Inches(1.5), Inches(3.4), Inches(0.85), fill=PRIMARY)
shape_text(c1, [("Flutter Web — Chrome", {"size": 14, "bold": True,
                                          "color": WHITE})])
c2 = rect(s, Inches(0.8), Inches(2.6), Inches(3.4), Inches(0.85), fill=PRIMARY)
shape_text(c2, [("Android APP (APKs)", {"size": 14, "bold": True,
                                        "color": WHITE})])
txt(s, Inches(0.8), Inches(3.55), Inches(3.4), Inches(0.3),
    [("One codebase · JWT session",
      {"size": 11.5, "color": GRAY, "align": PP_ALIGN.CENTER})])
gw = rect(s, Inches(5.1), Inches(1.85), Inches(3.6), Inches(1.25),
          fill=ACCENT, radius=0.12)
shape_text(gw, [
    ("nginx Gateway :7357", {"size": 14.5, "bold": True, "color": WHITE,
                             "sa": 2}),
    ("Caddy auto-TLS on Azure", {"size": 11.5, "color": WHITE}),
])
txt(s, Inches(5.1), Inches(3.2), Inches(3.6), Inches(0.3),
    [("static hosting + /api proxy",
      {"size": 11.5, "color": GRAY, "align": PP_ALIGN.CENTER})])
svc = [
    ("Auth API :3002", "PostgreSQL 5434", "login · JWT · recovery · search"),
    ("Chat API :3004", "PostgreSQL 5435", "friends · groups · AI · /ws calls"),
    ("Community API :3000", "PostgreSQL 5433", "activities · nearby people"),
    ("Family API :3003", "SQLite volume", "groups · consent tree"),
]
sx = [4.42, 6.62, 8.82, 11.02]
for (name, db, desc), x in zip(svc, sx):
    b = rect(s, Inches(x), Inches(4.1), Inches(2.05), Inches(1.35),
             fill=LIGHT, line=SECOND, line_w=Pt(1.5), radius=0.12)
    shape_text(b, [
        (name, {"size": 12.5, "bold": True, "color": PRIMARY, "sa": 1}),
        (db, {"size": 10.5, "bold": True, "color": SECOND, "sa": 1}),
        (desc, {"size": 9.5, "color": GRAY}),
    ], m=0.04)
txt(s, Inches(0.55), Inches(4.1), Inches(3.6), Inches(1.35),
    [("Docker Compose — every service + its own database",
      {"size": 12.5, "color": GRAY})], anchor=MSO_ANCHOR.MIDDLE)
arrow(s, Inches(4.25), Inches(1.93), Inches(5.08), Inches(2.3), w=2.2)
arrow(s, Inches(4.25), Inches(3.03), Inches(5.08), Inches(2.6), w=2.2)
arrow(s, Inches(8.73), Inches(2.62), Inches(5.1), Inches(4.3), w=1.6)
arrow(s, Inches(8.0), Inches(3.12), Inches(6.9), Inches(4.05), w=1.6)
arrow(s, Inches(7.9), Inches(3.12), Inches(9.2), Inches(4.05), w=1.6)
arrow(s, Inches(7.8), Inches(3.12), Inches(11.5), Inches(4.05), w=1.6)
arrow(s, Inches(7.8), Inches(3.12), Inches(4.6), Inches(4.3), w=1.6)
chips = ["Node.js / Express", "JWT everywhere", "WebRTC P2P + STUN",
         "PostgreSQL ×3 + SQLite", "Docker Compose ×4 stacks"]
xc0 = 0.8; cwc = 2.35; gpc = 0.12
for i, t in enumerate(chips):
    chip(s, Inches(xc0 + i * (cwc + gpc)), Inches(5.95), Inches(cwc),
         Inches(0.5), t, fill=LIGHT, color=PRIMARY, size=11.5)
notes(s, "[~60s] Presenter: WANGZUZAN.\n"
         "Walk top-down: one Flutter codebase serves web and Android; a "
         "single nginx gateway (Caddy TLS in production) proxies four "
         "independent services, each owning its database — three "
         "PostgreSQL instances plus SQLite for family. Every module "
         "accepts the JWT issued by my auth service; the family service "
         "even delegates verification to it. Docker Compose orchestrates "
         "all stacks. This slide frames everyone's five-minute slots.")

# ---- Slide 5: auth part 1 ----
s = add_slide()
slide_frame(s, "Authentication — Registration & Login", 5,
            owner="WANGZUZAN")
steps_flow(s, 0.5, 1.45, 3.5, 0.78, [
    ("Register", "email · username · password"),
    ("Email code", "SMTP 6-digit · time-boxed"),
    ("Login", "JWT + session version"),
    ("Protected access", "every API · stale tokens rejected"),
], gap=0.26)
card(s, Inches(6.3), Inches(1.45), Inches(6.6), Inches(3.35),
     "The user experience", [
         "• Registration enforces paired security question & answer "
         "(both filled or both empty)",
         "• Verification page with resend + single-use codes",
         "• Google Sign-In button — build-time client ID, degrades "
         "gracefully without it",
         "• Terms-of-service step before first login",
         "• Case-insensitive uniqueness: lower(email) / lower(username) "
         "indexes",
     ], tsize=15)
band(s, Inches(6.3), Inches(5.15), Inches(6.6), Inches(0.75),
     "Infrastructure: PostgreSQL 5434 + Adminer console + Docker stack",
     fill=SECOND, size=12.5)
band(s, Inches(0.5), Inches(5.75), Inches(5.2), Inches(0.95),
     "One login gate for every module — Chat, Community, Family and "
     "Profile all consume these endpoints.", size=12)
notes(s, "[~90s] Presenter: WANGZUZAN.\n"
         "Walk the flow left to right: register with a verified email "
         "(time-boxed SMTP code, resend support), login issuing a JWT that "
         "carries a session version. Google Sign-In verified server-side "
         "and linked via google_sub. Uniqueness is case-insensitive by "
         "design. Mention the infrastructure: dedicated PostgreSQL, Adminer "
         "console for the team, Docker stack — all built and owned by you.")

# ---- Slide 6: auth part 2 ----
s = add_slide()
slide_frame(s, "Authentication — Recovery & Security Engineering", 6,
            owner="WANGZUZAN")
steps_flow(s, 0.5, 1.4, 3.5, 0.72, [
    ("Forgot password", "choose a recovery path"),
    ("Email code path", "SMTP six-digit, time-boxed"),
    ("OR Security question", "5 fails → 15-minute lockout"),
    ("One-time credential", "single-use · valid 5 minutes"),
    ("Reset", "session version bumps — old JWTs die"),
], gap=0.2)
card(s, Inches(6.3), Inches(1.4), Inches(6.6), Inches(3.5),
     "Security engineering (OWASP [14] · NIST 800-63B [12])", [
         "• bcrypt password hashing — never reversible",
         "• Rate limiting on sensitive endpoints (auth_rate_limits)",
         "• Password reset or change invalidates every outstanding token",
         "• Google-only accounts supported without local passwords",
         "• Secrets in .env only — excluded from the repository",
         "• Incremental migration added security-question tables without "
         "touching existing accounts",
     ], tsize=15)
b = rect(s, Inches(6.3), Inches(5.15), Inches(6.6), Inches(0.75), fill=GREEN,
         radius=0.2)
shape_text(b, [("35 auth tests + 1 live PostgreSQL integration test — "
                "ALL PASS", {"size": 13.5, "bold": True, "color": WHITE})])
txt(s, Inches(6.3), Inches(6.05), Inches(6.6), Inches(0.75),
    [("Foundation for every module: Chat uses user search; Profile uses "
      "match candidates; Family delegates token checks to /auth/me.",
      {"size": 11.5, "color": GRAY, "italic": True})])
txt(s, Inches(0.5), Inches(6.35), Inches(5.2), Inches(0.5),
    [("Design goal: recovery that cannot be brute-forced or replayed.",
      {"size": 11.5, "color": GRAY, "italic": True})])
notes(s, "[~75s] Presenter: WANGZUZAN.\n"
         "Two recovery paths: an emailed code, or security questions with "
         "a lockout after five failures and a single-use five-minute "
         "reset credential. The key security property: any password change "
         "bumps the session version, instantly killing every outstanding "
         "token. bcrypt, rate limits, secrets outside the repo. 35 unit "
         "tests plus a live database integration test all pass. Close by "
         "handing over to Xuyongqi for the chat module.")

# =====================================================================
# SLOT 2 — XUYONGQI (~5:00): chat, four slides
# =====================================================================

XQ_S7 = ("[~75s] Slide 7 of 21 — Chat: the social loop.\n"
"My name is Xuyongqi, and I own the chat module — the main page and "
"every sub-page you are about to see.\n"
"Before two users can chat, they must become friends. The add-friend page "
"searches by email, username or full name through the authentication "
"service — so one search box covers every way you might know a person. "
"Sending a request is one tap; the other user sees a live red badge on "
"the bell icon of the home page, and can accept or decline. Once "
"accepted, the conversation appears in the chat list — the app's main "
"tab — with unread state tracked per user.\n"
"Behind the scenes, the friend relationship, the request lifecycle and "
"every message are persisted in the chat service's own PostgreSQL "
"database. The chat detail page supports text and voice messages — you "
"hold a button to record, and the clip is stored and replayed on both "
"sides.")

# ---- Slide 7: chat part 1 ----
s = add_slide()
slide_frame(s, "Chat — The Social Loop: Friends & Messaging", 7,
            owner="XUYONGQI")
steps_flow(s, 0.5, 1.4, 4.6, 0.8, [
    ("Search", "email / username / full name — via auth service"),
    ("Send request", "one tap from the result card"),
    ("Bell badge", "live count on the home page"),
    ("Accept / Decline", "friend relationship created"),
    ("Conversation", "appears in the chat list"),
], gap=0.18)
card(s, Inches(6.3), Inches(1.4), Inches(6.6), Inches(2.6),
     "One-to-one messaging", [
         "• Text + voice messages — hold to record, replay on both sides",
         "• Per-user read state — unread tracking in the chat list",
         "• Persisted in the chat PostgreSQL database (port 5435)",
         "• Chat REST client: ~730 lines covering the whole API surface",
     ], tsize=15)
band(s, Inches(6.3), Inches(4.35), Inches(6.6), Inches(0.8),
     "Friendship is the unit of access — only friends can message or "
     "call, enforced on both client and server.", size=12.5)
txt(s, Inches(6.3), Inches(5.4), Inches(6.6), Inches(1.2),
    [("Home page anchors the app: conversation list, AI preview entry and "
      "the request badge sit on the main tab every user opens first.",
      {"size": 12.5, "color": GRAY, "italic": True})])
notes(s, XQ_S7)

XQ_S8 = ("[~65s] Slide 8 of 21 — Chat: group governance.\n"
"Group chats follow a real-world governance model rather than a "
"free-for-all. The member who creates a group is its Owner — shown with "
"a gold badge. Owners appoint administrators, shown in blue, and owners "
"themselves cannot be muted or removed by anyone. Administrators can "
"mute or remove ordinary members, but they cannot touch other admins or "
"the owner.\n"
"When a muted member opens the input bar, they see an explicit red "
"restriction explaining they are muted — we deliberately show the rule "
"instead of silently dropping their messages, because silent failure "
"looks like a bug and breeds mistrust. Mutes can be lifted anytime; a "
"removed member immediately loses access to history and calls, but can "
"be invited back by the owner.")

# ---- Slide 8: chat part 2 ----
s = add_slide()
slide_frame(s, "Chat — Group Governance & Admin Tools", 8, owner="XUYONGQI")
hier = [
    ("Owner  (gold badge)", "creates the group · appoints / demotes admins "
     "· mutes or removes anyone · cannot be managed", ACCENT),
    ("Admin  (blue badge)", "mutes / removes ordinary members · cannot act "
     "on other admins or the owner", SECOND),
    ("Member", "full chat access · promoted or removed by those above",
     GRAY),
]
yy = Inches(1.4)
for name, desc, col in hier:
    c = rect(s, Inches(0.5), yy, Inches(6.4), Inches(1.05), fill=LIGHT,
             line=LINEC, line_w=Pt(1))
    chip(s, Inches(0.68), yy + Inches(0.28), Inches(1.85), Inches(0.5),
         name.split("  (")[0], fill=col, size=13)
    txt(s, Inches(2.7), yy + Inches(0.12), Inches(4.05), Inches(0.85),
        [(desc, {"size": 11.5})], anchor=MSO_ANCHOR.MIDDLE)
    yy += Inches(1.25)
card(s, Inches(7.25), Inches(1.4), Inches(5.65), Inches(3.55),
     "Visible rules, no silent failure", [
         "• Muted members see an explicit red restriction in the input "
         "bar — the rule is always shown, never hidden",
         "• Removal takes effect immediately: history and calls gone",
         "• Owner can re-invite a removed member anytime",
         "• Badges in the member panel: gold Owner, blue Admin, red "
         "muted-microphone icon",
         "• Actions live in each member's ⋮ menu — Promote, Demote, Mute, "
         "Unmute, Remove",
     ], tsize=14.5, bar=ACCENT)
band(s, Inches(0.5), Inches(5.35), Inches(12.4), Inches(0.75),
     "Governance model: authority is explicit, visible and reversible — "
     "trust is a design requirement, not an afterthought.", size=13)
txt(s, Inches(0.5), Inches(6.35), Inches(12.4), Inches(0.5),
    [("Demo: seeded group \u201cGroup Call Demo\u201d with four test accounts — "
      "roles exercised live in three browser windows.",
      {"size": 12, "color": GRAY, "italic": True})])
notes(s, XQ_S8)

XQ_S9 = ("[~95s] Slide 9 of 21 — Chat: real-time calls over WebRTC.\n"
"Calls are where this project went deepest technically. We implemented "
"voice and video calling with WebRTC — real peer-to-peer media that "
"never routes through our servers. The plumbing: the chat service "
"exposes an authenticated WebSocket; every offer, answer and ICE "
"candidate travels through it, gated by the same login token as "
"everything else. The connection has a heartbeat and reconnects with "
"exponential backoff from one to thirty seconds, so a flaky network "
"degrades gracefully instead of dropping calls.\n"
"One-to-one calls ring full-screen with accept and decline, a pulse "
"animation and a running timer. Group calls use a full mesh: every "
"participant holds one direct peer connection to every other "
"participant, using Google's public STUN servers. Any member can start "
"the call; online members get the full-screen invitation; and if you "
"open the chat while a call is already running, you see this banner — "
"'ongoing call, tap to join' — and join mid-call. Inside the call, "
"mute and camera toggles are track-level, so they propagate instantly "
"without renegotiation, and leaving tears down only your connections "
"while the call continues.")

# ---- Slide 9: chat part 3 ----
s = add_slide()
slide_frame(s, "Chat — Real-Time Calls (WebRTC)", 9, owner="XUYONGQI")
mm = rect(s, Inches(6.7), Inches(1.4), Inches(6.2), Inches(3.0), fill=LIGHT2,
          line=LINEC, line_w=Pt(1))
txt(s, Inches(6.9), Inches(1.5), Inches(5.8), Inches(0.35),
    [("Group call — full-mesh WebRTC (P2P media, Google STUN)",
      {"size": 13.5, "bold": True, "color": PRIMARY})])
A = (Inches(7.9), Inches(2.2)); B = (Inches(10.9), Inches(2.2))
C = (Inches(9.4), Inches(3.6))
def pdot(pos, label):
    d = s.shapes.add_shape(MSO_SHAPE.OVAL, pos[0] - Inches(0.4),
                           pos[1] - Inches(0.4), Inches(0.8), Inches(0.8))
    d.fill.solid(); d.fill.fore_color.rgb = SECOND
    d.line.color.rgb = WHITE; d.line.width = Pt(2); no_shadow(d)
    shape_text(d, [(label, {"size": 15, "bold": True, "color": WHITE})])
for p, q in ((A, B), (A, C), (B, C)):
    arrow(s, p[0] + Inches(0.42), p[1] + Inches(0.18),
          q[0] - Inches(0.42), q[1] - Inches(0.18), color=PRIMARY, w=2.0)
pdot(A, "A"); pdot(B, "B"); pdot(C, "C")
txt(s, Inches(6.9), Inches(3.85), Inches(5.9), Inches(0.45),
    [("one peer connection per pair · any member can start",
      {"size": 11.5, "color": GRAY, "align": PP_ALIGN.CENTER})])
card(s, Inches(0.45), Inches(1.4), Inches(5.9), Inches(1.75),
     "1-to-1 calls", [
         "• Full-screen incoming view — accept / decline, pulse animation",
         "• Running call timer · only friends can dial",
     ], tsize=14)
card(s, Inches(0.45), Inches(3.35), Inches(5.9), Inches(1.75),
     "Call controls", [
         "• Mute / camera toggles are track-level — propagate without "
         "renegotiation",
         "• Leaving tears down only your connections — the call continues",
     ], tsize=14)
card(s, Inches(0.45), Inches(5.3), Inches(5.9), Inches(1.45),
     "Signalling over the chat WebSocket", [
         "• /ws?token=JWT — same login gate as everything else",
         "• Heartbeat + exponential reconnect backoff (1–30 s) · 256 KB "
         "payload cap",
     ], tsize=14)
bn = rect(s, Inches(6.7), Inches(4.6), Inches(6.2), Inches(0.62),
          fill=PRIMARY, radius=0.5)
shape_text(bn, [("Ongoing call — tap to join  →  late joiners enter a "
                 "running call", {"size": 13.5, "bold": True,
                                   "color": WHITE})])
card(s, Inches(6.7), Inches(5.42), Inches(6.2), Inches(1.35),
     "Honest limitation", [
         "• Full mesh scales to ~4–6 active participants; beyond that "
         "uplink load degrades media",
         "• No TURN fallback — symmetric NATs can block connection",
     ], tsize=13, bar=ACCENT, fill=RGBColor(0xFB, 0xF3, 0xE4))
notes(s, XQ_S9)

XQ_S10 = ("[~65s] Slide 10 of 21 — Chat: AI assistant and engineering "
"discipline; hand-over to Yinghaozhe.\n"
"Finally, two things that round the module out. First, the AI "
"assistant tab: conversations are proxied through our backend to a "
"hosted GLM model, history is stored server-side, and the API key "
"exists only on the server — it never ships in the client build. The "
"feature is labelled as an AI assistant in the interface, because "
"hiding what is automated would be misleading.\n"
"Second, engineering discipline: the module's session-state and "
"storage logic are covered by automated test suites that run inside the "
"project's 105-test Flutter suite, and the whole flow was verified in "
"three browser windows simultaneously with seeded demo accounts.\n"
"In summary: friends, messaging, governed groups, peer-to-peer calls "
"and an honest AI assistant — one module, one owner, fully delivered "
"and tested. Next, Yinghaozhe will show the community module.")

# ---- Slide 10: chat part 4 ----
s = add_slide()
slide_frame(s, "Chat — AI Assistant & Engineering Discipline", 10,
            owner="XUYONGQI")
card(s, Inches(0.45), Inches(1.4), Inches(6.1), Inches(2.9),
     "AI assistant — honest by design", [
         "• Conversations proxied through the chat backend to a hosted "
         "GLM-4-flash model [16]",
         "• History stored server-side — available on any device",
         "• API key lives only on the server — never in the client build",
         "• Clearly labelled as an AI assistant in the interface — no "
         "pretending to be human",
     ], tsize=15)
card(s, Inches(6.75), Inches(1.4), Inches(6.1), Inches(2.9),
     "Backend surface (owned end-to-end)", [
         "• Friend lifecycle: send / accept / decline / remove",
         "• Conversations + messages with per-user read state",
         "• Groups: create, roles, mute, remove, members, leave, disband",
         "• Express + ws service · chat PostgreSQL on 5435 · Docker stack",
     ], tsize=15)
b = rect(s, Inches(0.45), Inches(4.65), Inches(12.4), Inches(0.75),
         fill=GREEN, radius=0.2)
shape_text(b, [("Session-state + storage test suites — passing inside "
                "the project's 105/105 Flutter suite",
                {"size": 13.5, "bold": True, "color": WHITE})])
card(s, Inches(0.45), Inches(5.7), Inches(12.4), Inches(1.1),
     "How it was verified", [
         "• Seeded demo accounts + demo group for repeatable integration "
         "runs",
         "• Three simultaneous browser windows exercising group calls and "
         "admin actions; backend killed mid-call to test reconnect",
     ], tsize=13, bar=SECOND)
notes(s, XQ_S10)

# =====================================================================
# SLOT 3 — YINGHAOZHE (~5:00): community, three slides
# =====================================================================

# ---- Slide 11: community part 1 ----
s = add_slide()
slide_frame(s, "Community — Activities & Attendance", 11, owner="YINGHAOZHE")
card(s, Inches(0.45), Inches(1.4), Inches(6.1), Inches(3.6),
     "Activity features", [
         "• Feed of activities within 500 m of your location",
         "• Create, edit and delete activities with full validation",
         "• Join / leave with a live attendee list",
         "• Current-attendee state on every card",
         "• Location check-ins record presence at activities",
         "• Consistent blue-and-white design across feed, map, list, form",
     ], tsize=15)
card(s, Inches(6.75), Inches(1.4), Inches(6.1), Inches(1.9),
     "One state, four views", [
         "• Feed, map, activity list and form share one state via "
         "ValueNotifiers",
         "• A join or check-in updates every view — no manual refreshes",
     ], tsize=14)
card(s, Inches(6.75), Inches(3.5), Inches(6.1), Inches(1.5),
     "Why it matters", [
         "• Communities act locally — the 500 m scope matches how "
         "neighbours actually organise",
     ], tsize=14)
band(s, Inches(0.45), Inches(5.35), Inches(12.4), Inches(0.75),
     "Attendance is an explicit act — joining and checking in are visible "
     "to others, which builds accountability into community life.",
     size=13)
txt(s, Inches(0.45), Inches(6.35), Inches(12.4), Inches(0.5),
    [("Backend: Node.js/Express on :3000 · community PostgreSQL on :5433 · "
      "Docker stack — owned end-to-end.",
      {"size": 12, "color": GRAY, "italic": True})])
notes(s, "[~95s] Presenter: YINGHAOZHE.\n"
         "Introduce yourself and the community module: the location-"
         "centred heart of the app. Activities within 500 metres with "
         "full create/join/attendance flows and check-ins. Emphasise the "
         "engineering: four views driven by one shared state via "
         "ValueNotifiers, so every action propagates everywhere. The "
         "500-metre scope matches how neighbours actually organise.")

# ---- Slide 12: community part 2 ----
s = add_slide()
slide_frame(s, "Community — Nearby People & the Map", 12,
            owner="YINGHAOZHE")
card(s, Inches(0.45), Inches(1.4), Inches(5.8), Inches(3.3), "Features", [
    "• Nearby-people discovery with opt-in location",
    "• Four range presets: 10 / 20 / 50 / 100 m",
    "• Presets stay synchronised with map zoom",
    "• OpenStreetMap view via flutter_map",
    "• Range circle drawn around your position",
    "• Device location via geolocator with permission flow",
], tsize=16)
mm = rect(s, Inches(6.9), Inches(1.4), Inches(6.0), Inches(3.3), fill=LIGHT2,
          line=LINEC, line_w=Pt(1))
ring = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(8.15), Inches(1.75),
                          Inches(2.6), Inches(2.6))
ring.fill.solid(); ring.fill.fore_color.rgb = RGBColor(0xD3, 0xE7, 0xF5)
ring.line.color.rgb = SECOND; ring.line.width = Pt(2.0); no_shadow(ring)
me = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(9.28), Inches(2.88),
                        Inches(0.35), Inches(0.35))
me.fill.solid(); me.fill.fore_color.rgb = ACCENT
me.line.color.rgb = WHITE; me.line.width = Pt(1.5); no_shadow(me)
for ang, dist in ((35, 0.7), (150, 0.95), (265, 0.6), (310, 1.15),
                  (200, 0.5)):
    px = 9.45 + dist * math.cos(math.radians(ang))
    py = 3.05 + dist * math.sin(math.radians(ang))
    p = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(px), Inches(py),
                           Inches(0.26), Inches(0.26))
    p.fill.solid(); p.fill.fore_color.rgb = PRIMARY
    p.line.fill.background(); no_shadow(p)
txt(s, Inches(11.1), Inches(2.75), Inches(1.6), Inches(0.5),
    [("You", {"size": 12, "bold": True, "color": ACCENT})])
txt(s, Inches(8.05), Inches(4.42), Inches(3.0), Inches(0.3),
    [("range circle · people dots", {"size": 11, "color": GRAY,
                                     "align": PP_ALIGN.CENTER})])
for i, r in enumerate(["10 m", "20 m", "50 m", "100 m"]):
    fill = SECOND if i == 3 else LIGHT
    col = WHITE if i == 3 else PRIMARY
    chip(s, Inches(11.15 + (i % 2) * 0.85), Inches(1.8 + (i // 2) * 0.6),
         Inches(0.78), Inches(0.45), r, fill=fill, color=col, size=11)
band(s, Inches(0.45), Inches(5.0), Inches(12.45), Inches(0.8),
     "Server caps protect privacy & performance:  query ≤ 100 m · "
     "≤ 100 candidates · ≤ 10 returned  —  switching range filters "
     "client-side (zero extra DB load)", size=13)
card(s, Inches(0.45), Inches(6.0), Inches(12.45), Inches(1.0), "Opt-in by design", [
    "Location is never collected silently: the device permission prompt "
    "gates everything, denial is handled gracefully, and only the current "
    "position is used — no location history is stored."], tsize=14,
    bar=GREEN)
notes(s, "[~105s] Presenter: YINGHAOZHE.\n"
         "The nearby-people map: four range presets synchronised with "
         "zoom, range circle, opt-in location via device permissions, "
         "graceful denial handling, no location history. Explain the "
         "deliberate server caps — 100 m maximum query, 100 candidates, "
         "10 returned — and that range switching filters client-side, so "
         "exploration costs no extra database load.")

# ---- Slide 13: community part 3 ----
s = add_slide()
slide_frame(s, "Community — Backend Design & Verification", 13,
            owner="YINGHAOZHE")
card(s, Inches(0.45), Inches(1.4), Inches(6.1), Inches(3.0),
     "API surface (Node.js / Express :3000)", [
         "• GET / POST / PUT / DELETE activities — full CRUD",
         "• POST + DELETE activity attendees (add / remove)",
         "• Current-attendee check on every card",
         "• POST nearby/people — latitude, longitude, radius in, capped "
         "candidates out",
         "• GET /health for the whole stack's startup checks",
     ], tsize=14.5)
card(s, Inches(6.75), Inches(1.4), Inches(6.1), Inches(3.0),
     "Engineering decisions", [
         "• Geo-radius search in plain SQL (haversine) — no PostGIS "
         "dependency",
         "• Hard caps chosen for privacy and performance, not convenience",
         "• Range switching filters the returned set — zero extra queries",
         "• ValueNotifier architecture keeps a 3,500-line page testable "
         "view by view",
     ], tsize=14.5)
b = rect(s, Inches(0.45), Inches(4.75), Inches(12.4), Inches(0.75),
         fill=GREEN, radius=0.2)
shape_text(b, [("nearby_map_location_test + nearby_people_service_test — "
                "passing inside the 105/105 Flutter suite",
                {"size": 13.5, "bold": True, "color": WHITE})])
card(s, Inches(0.45), Inches(5.8), Inches(12.4), Inches(1.0),
     "Repeatable demos", [
         "Seeded activities and check-in state ship with the one-click "
         "scripts, so every fresh start shows the same populated "
         "neighbourhood — a failing flow is a code problem, never a data "
         "problem."], tsize=13, bar=SECOND)
notes(s, "[~100s] Presenter: YINGHAOZHE.\n"
         "Walk the API surface and the two engineering decisions you would "
         "defend in review: plain-SQL geo search without PostGIS, and hard "
         "server caps with client-side filtering. Close with the two "
         "automated suites and the seeded demo data that makes every "
         "integration run repeatable. Hand over to Daizihong for the "
         "family module.")

# =====================================================================
# SLOT 4 — DAIZIHONG (~5:00): family, three slides
# =====================================================================

# ---- Slide 14: family part 1 ----
s = add_slide()
slide_frame(s, "Family — Groups & Daily Life", 14, owner="DAIZIHONG")
card(s, Inches(0.45), Inches(1.4), Inches(6.1), Inches(3.3),
     "Multi-group membership", [
         "• One user, several family groups — join with a real name and "
         "family role",
         "• Join preview: see the target group before any data is "
         "committed",
         "• Primary group switcher — your main family at a glance",
         "• Summary cards per group on the dashboard",
         "• Invite codes, leave, and role changes",
     ], tsize=15)
card(s, Inches(6.75), Inches(1.4), Inches(6.1), Inches(3.3),
     "Daily family life", [
         "• Activities and tasks per group",
         "• Shared notes",
         "• Manual daily check-ins — attendance is an explicit act, never "
         "inferred",
         "• Combined notification feed: nothing happens in a group you "
         "cannot see",
     ], tsize=15)
band(s, Inches(0.45), Inches(5.05), Inches(12.4), Inches(0.8),
     "Design principle: membership is never accidental — a wrong code or "
     "unwanted group cannot silently create a relationship.", size=13.5)
txt(s, Inches(0.45), Inches(6.1), Inches(12.4), Inches(0.75),
    [("Owned end-to-end: family UI (family_page.dart) + zero-dependency "
      "family service on :3003 + SQLite storage + Docker family stack "
      "(incl. demo variant).",
      {"size": 12, "color": GRAY, "italic": True})])
notes(s, "[~90s] Presenter: DAIZIHONG.\n"
         "Introduce yourself and the family module: family life in two "
         "layers — everyday groups first. Multi-membership with join "
         "previews requiring a real name and family role, a primary "
         "group, activities, tasks, notes and manual check-ins. Stress "
         "the design principle: membership is never accidental, and the "
         "notification feed keeps every group visible.")

# ---- Slide 15: family part 2 ----
s = add_slide()
slide_frame(s, "Family — The Consent-Based Family Tree", 15,
            owner="DAIZIHONG")
flow = [("Connection code", "requesting group shares a code"),
        ("Preview + label", "target sees who and what relationship"),
        ("Explicit consent", "no silent linking, ever"),
        ("Unanimous approval", "every affected admin approves"),
        ("Linked", "else reject / cancel / expire in 7 days")]
x0 = 0.45; fw = 2.42; fy = Inches(1.45)
for i, (t, d) in enumerate(flow):
    fill = PRIMARY if i == 4 else LIGHT
    tcol = WHITE if i == 4 else PRIMARY
    dcol = RGBColor(0xCF, 0xE2, 0xF2) if i == 4 else GRAY
    b = rect(s, Inches(x0 + i * (fw + 0.13)), fy, Inches(fw), Inches(1.05),
             fill=fill, line=SECOND if i != 4 else PRIMARY, line_w=Pt(1.2),
             radius=0.14)
    shape_text(b, [(t, {"size": 12.5, "bold": True, "color": tcol, "sa": 1}),
                   (d, {"size": 10, "color": dcol})], m=0.04)
    if i < 4:
        arrow(s, Inches(x0 + (i + 1) * fw + i * 0.13 + 0.02),
              fy + Inches(0.52), Inches(x0 + (i + 1) * (fw + 0.13) - 0.02),
              fy + Inches(0.52), w=1.8)
txt(s, Inches(0.45), Inches(2.6), Inches(12.45), Inches(0.35),
    [("Role / code / topology changes invalidate pending requests — stale "
      "approvals can never be replayed.",
      {"size": 12.5, "color": GRAY, "italic": True})])
card(s, Inches(0.45), Inches(3.1), Inches(6.1), Inches(2.5),
     "Why unanimous consent?", [
         "• A tree link affects two groups, not one — so every affected "
         "administrator must agree",
         "• Requests expire after 7 days — consent cannot be banked",
         "• Administrators can disconnect their group's links; owners can "
         "leave the tree",
         "• Links grant no access to the other family's private records",
     ], tsize=14.5, bar=ACCENT)
card(s, Inches(6.85), Inches(3.1), Inches(6.05), Inches(2.5),
     "Graph rules (applied graph theory)", [
         "• No cycles — the tree stays a tree",
         "• Connected component capped at 50 groups",
         "• Approval and disconnection execute inside SQLite transactions "
         "— no half-connected states",
         "• Invalidation on role / code / topology change prevents "
         "replay attacks",
     ], tsize=14.5)
band(s, Inches(0.45), Inches(5.85), Inches(12.45), Inches(0.75),
     "Consent is engineered, not assumed — the ethics highlight of the "
     "whole project.", fill=ACCENT, size=13.5)
notes(s, "[~100s] Presenter: DAIZIHONG.\n"
         "The centrepiece: connecting two separate groups requires a "
         "connection code, a visible preview with a relationship label, "
         "explicit consent, and the unanimous approval of every affected "
         "administrator. Requests can be rejected, cancelled, or expire "
         "after seven days; topology changes invalidate pending approvals "
         "so stale consent can never be replayed. Links never expose "
         "another family's private records. This is consent as an "
         "engineering property.")

# ---- Slide 16: family part 3 ----
s = add_slide()
slide_frame(s, "Family — Tree Canvas, Backend & Tests", 16,
            owner="DAIZIHONG")
tm = rect(s, Inches(0.45), Inches(1.4), Inches(6.1), Inches(3.4),
          fill=LIGHT2, line=LINEC, line_w=Pt(1))
nodes = [(1.0, 2.0), (2.5, 2.8), (3.95, 2.0), (5.3, 2.9)]
links = [(0, 1), (1, 2), (2, 3)]
for a, b_ in links:
    arrow(s, Inches(nodes[a][0] + 0.45), Inches(nodes[a][1] + 0.2),
          Inches(nodes[b_][0]), Inches(nodes[b_][1]), color=SECOND, w=1.8)
for i, (nx, ny) in enumerate(nodes):
    d = rect(s, Inches(nx), Inches(ny), Inches(0.95), Inches(0.55),
             fill=PRIMARY, radius=0.5)
    shape_text(d, [(f"Group {chr(65 + i)}", {"size": 10.5, "bold": True,
                                              "color": WHITE})], m=0.02)
txt(s, Inches(0.6), Inches(4.35), Inches(5.8), Inches(0.4),
    [("Tree canvas: drag · pinch-zoom · \u201cshow all\u201d · 50-group cap · "
      "group detail sheets",
      {"size": 11.5, "color": GRAY, "align": PP_ALIGN.CENTER})])
card(s, Inches(6.85), Inches(1.4), Inches(6.05), Inches(3.4),
     "Zero-dependency backend (a deliberate trade-off)", [
         "• Raw node:http router — no Express, no npm dependencies",
         "• node:sqlite with synchronous API + transactions",
         "• Token verification delegated to the auth service /auth/me — "
         "no duplicated auth",
         "• Per-user rate limiting, hand-rolled",
         "• Demo mode with isolated data for the portable distribution",
         "• Trade-off: embedded SQLite suits family scale; PostgreSQL "
         "consistency remains future work",
     ], tsize=14, bar=ACCENT)
b = rect(s, Inches(0.45), Inches(5.15), Inches(12.45), Inches(0.75),
         fill=GREEN, radius=0.2)
shape_text(b, [("34 Flutter tests + 35 backend tests — ALL PASS "
                "(permissions, consent, graph rules, canvas)",
                {"size": 13.5, "bold": True, "color": WHITE})])
txt(s, Inches(0.45), Inches(6.1), Inches(12.45), Inches(0.75),
    [("Documented as handoff specifications (feature plan + review notes) "
      "so the team integrated against agreed behaviour, not "
      "interpretation.",
      {"size": 12, "color": GRAY, "italic": True})])
notes(s, "[~110s] Presenter: DAIZIHONG.\n"
         "The tree canvas: a custom interactive surface — drag, pinch-zoom, "
         "show-all — with gesture recognisers isolated from state updates "
         "so a pinch during layout cannot corrupt positions. Then the "
         "backend: deliberately zero-dependency (raw node:http + "
         "node:sqlite), auth delegated to the auth service, transactional "
         "approval. Be honest about the trade-off: embedded SQLite suits "
         "family scale. 34 Flutter plus 35 backend tests pass. Hand over "
         "to Huangzhiyong for the profile module and the project close.")

# =====================================================================
# SLOT 5 — HUANGZHIYONG (~5:00): profile + verification + ethics + close
# =====================================================================

# ---- Slide 17: profile part 1 ----
s = add_slide()
slide_frame(s, "Profile — Server-First Editing", 17, owner="HUANGZHIYONG")
steps_flow(s, 0.5, 1.5, 5.3, 0.86, [
    ("Edit", "validated: name, username 3–30, phone format"),
    ("Submit", "busy state — no duplicate submits"),
    ("Server accepts", "only then local state refreshes"),
    ("Fail = keep input", "real error shown, edits preserved"),
], gap=0.26, hi=2)
card(s, Inches(0.5), Inches(6.05), Inches(5.3), Inches(0.95),
     "Blocked states", ["Saving disabled while offline / stale — no "
                        "placeholder data can reach the database."],
     tsize=13, bar=RED)
card(s, Inches(6.3), Inches(1.5), Inches(6.6), Inches(3.15),
     "State correctness across the app", [
         "• Cleared-on-server fields truly clear locally (explicit empty "
         "vs missing fields)",
         "• Email read-only — it anchors login identity; reopening needs "
         "a backend verification flow",
         "• Keep-alive tabs: unsaved edits survive navigation and "
         "password pages",
         "• Logout asks confirmation — resets profile + chat state, no "
         "account-to-account leakage",
         "• Refactor: 1,458 → 1,072 lines, extracted + fully retested",
     ], tsize=14.5)
card(s, Inches(6.3), Inches(4.85), Inches(6.6), Inches(1.5),
     "Model-layer mapping (profile_model)", [
         "• Legacy single-interest accounts mapped into the new list model",
         "• Missing birth date omitted from the request body — never a "
         "placeholder",
     ], tsize=13)
notes(s, "[~100s] Presenter: HUANGZHIYONG.\n"
         "Introduce yourself: the profile module, where correctness is the "
         "feature. Server-first saving: local state updates only after the "
         "server accepts; duplicate submits blocked; offline or stale "
         "states can never write placeholder data. Fields cleared on the "
         "server truly clear. Email read-only with a rationale. Keep-alive "
         "tabs preserve unsaved edits; logout confirms and resets profile "
         "plus chat state so accounts never leak into each other.")

# ---- Slide 18: profile part 2 ----
s = add_slide()
slide_frame(s, "Profile — Matching, Verification & Discipline", 18,
            owner="HUANGZHIYONG")
card(s, Inches(0.45), Inches(1.4), Inches(6.1), Inches(2.7),
     "Interest Match & Recommended", [
         "• Candidates load lazily on first tab entry — profile viewing "
         "stays fast",
         "• Zero-percent matches filtered; empty states explain why",
         "• Results cached by profile + candidate identities — no "
         "recomputation on tab switches",
         "• Google-photo avatars with letter fallback; two-row interest "
         "input for narrow screens",
     ], tsize=14.5)
card(s, Inches(6.75), Inches(1.4), Inches(6.1), Inches(2.7),
     "Behavioural test suites (authored by me)", [
         "• profile_model_test: empty-field clearing, missing-field "
         "fallback, legacy interests, logout reset",
         "• profile_page_state_test: offline save blocked, tab keep-alive, "
         "logout confirmation",
         "• The suites caught real regressions during the refactor — "
         "including a controller leak",
     ], tsize=14.5)
b = rect(s, Inches(0.45), Inches(4.45), Inches(12.4), Inches(0.75),
         fill=GREEN, radius=0.2)
shape_text(b, [("Nov 10 hardening verified: flutter analyze 0 issues · "
                "105/105 tests · release web build OK",
                {"size": 13.5, "bold": True, "color": WHITE})])
card(s, Inches(0.45), Inches(5.5), Inches(12.4), Inches(1.3),
     "Known gaps, documented honestly", [
         "• Email editing awaits a backend verification endpoint · match "
         "candidates capped at 200 per request, no pagination · avatars "
         "support Google URLs only",
         "• Every gap was recorded in a dated changelog with verification "
         "records — future work, never silently ignored",
     ], tsize=13, bar=ACCENT, fill=RGBColor(0xFB, 0xF3, 0xE4))
notes(s, "[~90s] Presenter: HUANGZHIYONG.\n"
         "Matching tabs: lazy loading, zero-percent filtering, "
         "identity-keyed caching, avatars. Then the discipline story: "
         "behavioural test suites that caught real regressions, the "
         "November hardening round verified end-to-end (clean analyser, "
         "105 of 105 tests, successful release build), and known gaps "
         "documented honestly in a dated changelog.")

# ---- Slide 19: project results (closing speaker) ----
s = add_slide()
slide_frame(s, "Project Results — Verification & Deployment", 19,
            right_tag="Closing: whole-project results")
stats = [("105 / 105", "Flutter tests passing"),
         ("≈ 70", "backend tests passing (auth + family)"),
         ("4 + 1", "microservices + gateway"),
         ("~30k", "lines of code (Dart + JS)"),
         ("0", "analyser issues, errors or warnings")]
x0 = 0.45; cw = 2.42; gp = 0.13
for i, (big, small) in enumerate(stats):
    b = rect(s, Inches(x0 + i * (cw + gp)), Inches(1.45), Inches(cw),
             Inches(1.35), fill=LIGHT, line=SECOND, line_w=Pt(1.25),
             radius=0.12)
    shape_text(b, [
        (big, {"size": 24, "bold": True, "color": PRIMARY, "sa": 2}),
        (small, {"size": 11, "color": GRAY})], m=0.04)
txt(s, Inches(0.45), Inches(3.05), Inches(12.4), Inches(0.35),
    [("Deployment (Aim 7):", {"size": 15, "bold": True, "color": PRIMARY})])
deps = [("One-click local", "RunProdWeb: 4 stacks + demo data + nginx :7357"),
        ("Portable ZIP", "runs from spaced / Chinese-named paths"),
        ("Public demo", "Cloudflare Quick Tunnel (temporary URL)"),
        ("Azure production", "Caddy automatic TLS on 80 / 443"),
        ("Android APKs", "universal 92 MB · arm64 33 MB · arm32 25 MB")]
for i, (t, d) in enumerate(deps):
    b = rect(s, Inches(0.45 + i * 2.55), Inches(3.45), Inches(2.42),
             Inches(1.25), fill=LIGHT2, line=LINEC, line_w=Pt(1),
             radius=0.12)
    shape_text(b, [(t, {"size": 12.5, "bold": True, "color": PRIMARY,
                        "sa": 2}),
                   (d, {"size": 10.5, "color": DARK})], m=0.06)
lim = rect(s, Inches(0.45), Inches(5.0), Inches(12.45), Inches(1.75),
           fill=RGBColor(0xFB, 0xF3, 0xE4), line=ACCENT, line_w=Pt(1.5),
           radius=0.1)
shape_text(lim, [
    ("Honest limitations (critical analysis):",
     {"size": 14.5, "bold": True, "color": RGBColor(0x9C, 0x66, 0x12),
      "align": PP_ALIGN.LEFT, "sa": 3}),
    ("• Mesh calls scale to ~4–6 active participants; no TURN fallback "
     "behind symmetric NATs   • Matching capped at 200 candidates / "
     "request, no pagination",
     {"size": 12.5, "align": PP_ALIGN.LEFT, "sa": 2}),
    ("• Email read-only pending backend verification; avatars Google-URL "
     "only   • No iOS build (Apple toolchain); family tree needs manual "
     "refresh",
     {"size": 12.5, "align": PP_ALIGN.LEFT, "sa": 2}),
    ("• Validation = automated suites + scripted scenarios; no load "
     "testing or external user trials yet — defines the next iteration's "
     "roadmap.",
     {"size": 12.5, "align": PP_ALIGN.LEFT}),
], align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.MIDDLE, m=0.2)
notes(s, "[~80s] Presenter: HUANGZHIYONG (closing member — whole-project "
         "view).\n"
         "Zoom out to the whole project: 105 of 105 Flutter tests, about 70 "
         "backend tests, zero analyser issues, ~30k lines. Deployment at "
         "four levels: double-click local, portable ZIP, public tunnel, "
         "Azure with TLS, plus three Android packages. Present the "
         "limitations honestly — they are the roadmap, not failures.")

# ---- Slide 20: ethics ----
s = add_slide()
slide_frame(s, "Ethics, Privacy & Security", 20)
cards = [
    ("Privacy [13]", ["Privacy Act 1988 + Australian Privacy Principles as "
     "guiding framework", "Data only for declared functions, on "
     "operator-controlled infrastructure, never sold or used for ads"]),
    ("Security [14][15]", ["bcrypt + NIST 800-63B [12]; JWT invalidation on "
     "reset", "Rate limits, lockouts, single-use codes, HTTPS (Let's "
     "Encrypt), secrets excluded from repository"]),
    ("Consent by design", ["Family tree: code + preview + explicit consent + "
     "unanimous admin approval", "Location opt-in and radius-bounded; not "
     "directed at minors (age declaration = future work)"]),
    ("Third parties & misuse", ["Google Sign-In and GLM AI disclosed and "
     "labelled in-app; STUN sees IPs during calls", "Moderation tools: "
     "owner/admin mute & remove; no injury or financial risk; free web + "
     "25 MB low-end package (equity)"]),
]
xs = [0.45, 6.75]
ys = [1.35, 4.2]
for i, (t, body) in enumerate(cards):
    card(s, Inches(xs[i % 2]), Inches(ys[i // 2]), Inches(6.1),
         Inches(2.7), t, body, tsize=16, bsize=13)
notes(s, "[~55s] Presenter: HUANGZHIYONG.\n"
         "Ethics is engineered, not bolted on: the Privacy Act and APPs "
         "guide data handling; security follows NIST and OWASP with real "
         "session invalidation; consent is explicit in the family tree and "
         "opt-in for location; third-party AI and Google sign-in are "
         "disclosed; moderation tools cover misuse; equity considered via "
         "free web access and a 25 MB low-end package.")

# ---- Slide 21: conclusion ----
s = add_slide()
slide_frame(s, "Conclusion & Team", 21)
bandc = rect(s, Inches(0.45), Inches(1.35), Inches(12.45), Inches(1.1),
             fill=PRIMARY, radius=0.12)
shape_text(bandc, [("Aims 1–6 delivered and verified · Aim 7 delivered with "
                    "maintenance — one integrated platform, industry-grade "
                    "engineering, deployable from laptop to cloud.",
                    {"size": 16, "bold": True, "color": WHITE})])
txt(s, Inches(0.45), Inches(2.75), Inches(12.4), Inches(0.4),
    [("Individual ownership — every member delivered, tested and "
      "integrated on time:",
      {"size": 15, "bold": True, "color": PRIMARY})])
team2 = [
    ("WANGZUZAN", "Auth backend, database and all account-security UI"),
    ("XUYONGQI", "Chat pages, chat service, WebRTC calls and signalling"),
    ("YINGHAOZHE", "Community UI, activity/nearby backend and geo queries"),
    ("DAIZIHONG", "Family groups, consent tree, zero-dependency service"),
    ("HUANGZHIYONG", "Profile workflow, matching tabs, state correctness"),
]
yy = Inches(3.25)
for name, desc in team2:
    c = rect(s, Inches(0.45), yy, Inches(12.45), Inches(0.58), fill=LIGHT2,
             line=RGBColor(0xD9, 0xE4, 0xEF), line_w=Pt(0.75), radius=0.5)
    n = rect(s, Inches(0.58), yy + Inches(0.07), Inches(1.9), Inches(0.44),
             fill=PRIMARY, radius=0.5)
    shape_text(n, [(name, {"size": 12, "bold": True, "color": WHITE})],
               m=0.02)
    txt(s, Inches(2.65), yy + Inches(0.05), Inches(10.0), Inches(0.45),
        [(desc, {"size": 13, "color": DARK})], anchor=MSO_ANCHOR.MIDDLE)
    yy += Inches(0.68)
ty = rect(s, Inches(0.45), Inches(6.75), Inches(12.45), Inches(0.55),
          fill=ACCENT, radius=0.5)
shape_text(ty, [("Thank you — questions welcome.",
                 {"size": 16, "bold": True, "color": WHITE})])
notes(s, "[~45s] Presenter: HUANGZHIYONG (close).\n"
         "Close with the one-liner: seven aims, five module owners, every "
         "part delivered with tests before each integration checkpoint. "
         "Each member just presented their own ownership end-to-end. Thank "
         "the audience and invite questions — invite the whole team to "
         "answer per module.")

out = r"PPT\GlobalVillage_Group_Presentation.pptx"
prs.save(out)
print("Saved:", out, "—", len(list(prs.slides)), "slides")
