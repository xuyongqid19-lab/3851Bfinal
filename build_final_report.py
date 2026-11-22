# -*- coding: utf-8 -*-
"""Builds the COMP3851B group final report (.docx) for the Global Village project.

Run:  python build_final_report.py
Output: final report/GlobalVillage_Final_Report_COMP3851B.docx
Structure: group section (~2,500 words) + individual section for Xu Yongqi
(~1,000 words, per the course spec's "Individual section: 1,000 words").
Combined length target: <= 3,500 words.
"""
import os
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "final report")
OUT_DOCX = os.path.join(OUT_DIR, "GlobalVillage_Final_Report_COMP3851B.docx")

# ----------------------------------------------------------------------------
# 1. REPORT CONTENT — GROUP SECTION ------------------------------------------
# ----------------------------------------------------------------------------

TITLE = "Global Village: A Cross-Platform Community Application Connecting Neighbours, Families and Friends"

BACKGROUND = [
    "Global Village was designed and built during a two-semester Work Integrated Learning placement with the School of "
    "Information and Physical Sciences at the University of Newcastle. The placement operates like an industry software "
    "team: five student engineers, an academic supervisor as client, documented requirements, interim deliverables and "
    "hard deadlines. The problem domain chosen by the team is everyday social connection. The World Health Organization "
    "now treats loneliness and social isolation as global public-health priorities (WHO 2023), and Australian reporting "
    "indicates that a substantial share of adults experience persistent loneliness (AIHW 2023). Urban life weakens "
    "exactly the informal ties — neighbours, local activities and extended family — that historically provided "
    "day-to-day support.",

    "The object of the work is the fragmentation of everyday social life across single-purpose applications. A typical "
    "household coordinates family matters in one messaging app, discovers local activities on an event platform and "
    "shares photographs through a third service, with no shared identity, no consistent privacy model and no community "
    "ownership of the data. The same family reunion is planned in a chat group, its meeting point pinned on one map "
    "service and its photographs shared by another, while neighbours two streets away organise a clean-up day on a "
    "platform the family never sees. For extended families spread across cities or countries, there is no lightweight "
    "platform that combines private communication, community engagement and family organisation behind one login.",

    "Two representative competitors frame the design space. WeChat dominates everyday communication in many communities, "
    "offering group chats, voice and video calls and social feeds (Tencent n.d.); however, it is a closed, centrally "
    "controlled ecosystem with no geolocated activity discovery, no family-organisation features and persistent public "
    "concern about the breadth of data it collects. Meetup excels at discovering nearby activities and interest groups "
    "(Meetup Inc. n.d.), but it is event-centric rather than people-centric: it provides no private family space, no "
    "built-in messaging or calling, and no concept of a household or kinship group. Global Village occupies the gap "
    "between these products: one cross-platform application in which neighbourhood, family and friendship communities "
    "are first-class and interconnected.",

    "The motivation is partly personal: as an international student team, the members experienced directly how hard it "
    "is to stay connected with family abroad while building new local ties after relocation. At present the professional "
    "community addresses the problem by stacking multiple single-purpose applications and accepting each platform's data "
    "practices. Global Village instead integrates identity, real-time communication, geolocated community activities, "
    "family groups and a novel group-based family tree into a modular, self-hostable microservice architecture, so that "
    "a small organisation or community can run the platform itself and keep members' data under its own control. Beyond "
    "the social motivation there is an engineering one: independent modules let each social domain evolve, scale and be "
    "tested without destabilising the others — a property the team exploited to divide the work across five members. The "
    "two-semester objective was therefore not a prototype but a deployable product: working software, automated tests, "
    "production deployment and handoffs.",
]

AIMS_INTRO = (
    "The project defined seven aims, scaffolding from identity and communication foundations to the community, "
    "family and profile domains and finally to deployment and quality assurance; each is attached to a deliverable, "
    "with status shown inline and in Table 1."
)

AIMS = [
    ("A1. Secure identity platform (Completed).",
     "Deliver an email-verified account system — registration with six-digit codes, login with lockout, Google "
     "Sign-In, recovery by email code or security questions, and logged-in password change — as the reusable Auth API."),
    ("A2. Private messaging and social graph (Completed).",
     "Deliver friend requests and one-to-one and group messaging carrying text, voice and location content, with read "
     "receipts and server-enforced group governance (owner, admin and member roles; promote, demote, mute, remove)."),
    ("A3. Real-time calls (Completed).",
     "Deliver WebRTC one-to-one and multi-party group calls, with WebSocket signalling and server-side authorisation "
     "so only friends, or fellow group members, can call."),
    ("A4. Geolocated community engagement (Completed).",
     "Deliver community activity creation, discovery, attendance and an interactive map, plus consent-based "
     "nearby-people discovery with positions expiring within minutes."),
    ("A5. Family organisation and tree connections (Completed; one refinement ongoing).",
     "Deliver family groups with activities, daily check-in tasks and health notes, and a group-based family tree "
     "whose merges require unanimous approval by every affected family."),
    ("A6. Personal profile and matching (Completed).",
     "Deliver an editable profile with interests and custom categories that drives match and recommendation views and "
     "underpins identity across modules."),
    ("A7. Deployment and quality assurance (Mostly completed).",
     "Deliver one-command Docker deployment, a public HTTPS deployment on Azure, Android release packages and an "
     "automated regression suite exceeding 220 tests; a continuous-integration pipeline remains future work."),
]

METHODS = [
    "Work followed an incremental, documentation-driven cycle. Ownership was split into five modules — identity "
    "(Wang), chat (Xu), community (Ying), family (Dai) and profile (Huang) — with integration and deployment "
    "shared. The team met weekly with supervisor reviews; merges followed a documented protocol accepted only after "
    "the full regression suite passed. Part A requirements were adjusted as the design matured.",

    "The frontend is one Flutter application for web and Android (Aims A1–A6) (Google n.d.). The backend is four "
    "independently deployable Node.js microservices: Express for Auth (A1), Chat (A2–A3) and Community (A4), and a "
    "zero-dependency node:http service for Family (A5). Each service owns its database — PostgreSQL 16 for Auth, "
    "Chat and Community (PostgreSQL Global Development Group n.d.), SQLite in WAL mode for Family — and ships in its "
    "own Compose stack (Docker Inc. n.d.). Cross-service identity validates the JSON Web Token (Jones, Bradley & "
    "Sakimura 2015) against the Auth API; no database is shared. Passwords are hashed with bcrypt (Provos & "
    "Mazières 1999) per NIST guidance (Grassi, Garcia & Fenton 2017); calls use WebRTC (W3C 2021) over WebSocket "
    "signalling; community geo-discovery combines grid cells with Haversine distances; family-tree merges follow "
    "connection codes, consent snapshots and unanimous approval (A5).",

    "Self-directed learning was planned: WebRTC mesh topologies, session-version token revocation, SQLite WAL, "
    "multi-stack Docker networking and database-free backend testing were learned outside the curriculum and applied "
    "to Aims A1–A7. Verification accompanied every increment: static analysis plus 105 Flutter tests, 120 backend "
    "API tests and two end-to-end WebSocket scripts gated each merge (A7).",
]

RESULTS_5_1 = [
    "The delivered system is a complete working platform, not a prototype: one Flutter application (63 Dart "
    "files, approximately 23,000 lines) serving web and Android, four independently deployable Node.js microservices, "
    "and token-validated integration with no shared database (Figure 1; Table 2). Database-per-module was a "
    "deliberate decision. Identity, messages, community and family data have different privacy and retention needs, "
    "and separation let five members develop, test and release in parallel. The accepted cost is a mirrored public "
    "profile row per downstream service and cross-service reads a monolith would not need; the benefit is a narrow "
    "blast radius and no single database holding every category of user data.",
]

RESULTS_5_2 = [
    "Aim A1 is fully delivered. Registration stores a pending record and emails a six-digit code valid for ten "
    "minutes (five attempts, thirty-minute expiry); accounts lock for fifteen minutes after five failed logins, and "
    "unknown emails are compared against a dummy bcrypt hash so responses cannot reveal whether an account exists. "
    "Verification and reset codes are stored only as HMAC-SHA256 digests with timing-safe comparison, and rate "
    "limits persist in PostgreSQL across restarts and instances. Passwords are hashed with bcrypt at cost 12, "
    "following NIST authentication guidance (Grassi, Garcia & Fenton 2017). Google Sign-In is verified server-side "
    "against the registered client ID (Google Developers n.d.), and an optional security-question path (three "
    "individually hashed answers) provides recovery without email dependency. A session-version counter revokes "
    "every outstanding token the moment a password changes. The design is defence in depth rather than a single "
    "barrier: enumeration, brute force, token theft and reset-code leakage each meet a separate control. The main "
    "limitation is the absence of a second factor; email is a single verification point of failure, softened by "
    "the security-question path.",
]

RESULTS_5_3 = [
    "Aims A2 and A3 are delivered end-to-end. Users find friends by email, username or name and manage requests "
    "from a badge in the chat list. One shared page serves one-to-one and group threads carrying text (≤2,000 "
    "characters), voice and location messages with read receipts. Group governance is enforced server-side through "
    "a role rank (owner above admin above member): admins cannot act on other admins or the owner, muted members "
    "are blocked at the API, and removal revokes access immediately. Calls use WebRTC (W3C 2021) with WebSocket "
    "signalling (Mozilla n.d.) reusing the login token; one-to-one offers are forwarded only after the server "
    "re-verifies the friendship, and group rooms require membership. Group calls use a full mesh in which every "
    "participant holds one peer connection to every other participant and joiners always issue the offers — a rule "
    "that structurally prevents offer glare. Late joiners see an ongoing-call banner; an optional AI assistant "
    "streams replies over server-sent events with a twenty-message context.",

    "The critical analysis is less flattering. The mesh is the weakest result: links grow quadratically, capping "
    "practical group calls at roughly six to eight participants before browsers degrade — a selective forwarding "
    "unit would be the industry answer but was out of scope. With only public STUN servers and no TURN relay, "
    "members behind symmetric NAT cannot connect. Call rooms live in server memory, so a restart drops calls and "
    "horizontal scaling would need a shared room store. Message content is persisted unencrypted: privacy rests on "
    "database isolation and transport security in production, not on end-to-end encryption.",
]

RESULTS_5_4 = [
    "Aim A4 is delivered with two discovery mechanisms. Community activities support creation, editing and deletion "
    "with ownership checks, attendance, and discovery filtered around the caller's position by 0.0045-degree grid "
    "cells, capped at 100 results. Nearby-people discovery stores coordinates for five minutes only, caps the "
    "radius at 500 metres with user-selectable tiers, pre-filters by grid cell, then applies exact Haversine "
    "distances and returns at most ten people with coarse proximity labels. An interactive map unifies activities "
    "and nearby members. The grid pre-filter was verified against brute-force filtering, trading small boundary "
    "error for large query savings at community scale. The five-minute time-to-live deliberately gives up "
    "continuous presence in exchange for privacy — a design choice, not an omission. Limitations: coordinates are "
    "client-reported and unverifiable — acceptable for discovery, not safety-critical uses — and there are no "
    "activity reminders or recency ranking yet.",
]

RESULTS_5_5 = [
    "Aim A5 is delivered by a service written with zero third-party dependencies on node:http and SQLite in WAL "
    "mode — a deliberate constraint removing supply-chain risk and keeping the module auditable. Families carry "
    "owner, admin and member roles with rotating invite codes; records cover activities, daily check-ins "
    "and health notes with an unread-events feed. The family tree is group-based rather than a person-level "
    "genealogy: each family owns a rotatable connection code, and a merge proposal records a SHA-256 consent "
    "snapshot of both sides before any administrator decides. A merge takes effect only when every affected "
    "family's administrators approve within seven days, and connected components are capped at fifty families. "
    "Identity tags (family and personal, five each, thirty colours), component-wide person search and in-app "
    "notifications complete the layer; a fictional demo family runs behind a flag.",

    "The unanimous-approval rule is ethically conservative — no family is merged into another's tree silently — "
    "but can stall when an administrator is inactive; the seven-day expiry is the designed mitigation, and code "
    "rotation invalidates stale requests. Disconnects split the component cleanly and notify affected members, "
    "preserving an acyclic forest. Limitations: two automated check-in types (login streaks and exercise targets) "
    "remain specified but unimplemented; and SQLite's single-writer model caps write throughput, which "
    "family-scale traffic does not approach.",
]

RESULTS_5_6 = [
    "Aim A6 is delivered. The profile API exposes name, unique username, phone, community, address and birth "
    "date; interests (up to ten, plus five custom categories) are stored as JSONB columns. The matching endpoint "
    "returns up to 200 candidates but omits phone numbers and addresses, so matching can never leak contact "
    "details. A 10 November hardening pass converted the page to server-truth saving (edits re-read from the API, "
    "never trusted from local state), made email read-only, preserved unsaved edits across tabs, added logout "
    "confirmation and removed demo data; the page was refactored from roughly 1,458 to 1,074 lines by extracting "
    "the Interest Match and Recommended views into a shared library. Limitations: avatars are sourced only from "
    "Google account photos because image upload was descoped, and matching is plain interest overlap — no "
    "weighting, history or collaborative filtering.",
]

RESULTS_5_7 = [
    "Aim A7 is delivered for both local and cloud paths. Six Docker Compose stacks bring up the four APIs, their "
    "databases, an administration panel and the nginx gateway. A double-click launcher starts every stack, seeds "
    "demo accounts idempotently and serves the prebuilt web client; a Cloudflare tunnel script exposes temporary "
    "demonstrations. Production runs eight containers on an Azure student virtual machine behind Caddy "
    "automatic HTTPS (deployed 10 November 2026; https://global-village-haozhe.malaysiawest.cloudapp.azure.com), "
    "and three Android packages let phones join over the local network. Verification is regression-based and fully "
    "scripted (Table 3): 105 Flutter tests, 75 Auth and 45 Family API tests, two end-to-end WebSocket scripts and "
    "clean static analysis on the delivered build. Limitations: no continuous-integration pipeline exists, so the "
    "suite runs manually before each merge; all services are single-instance; and iOS was out of scope for lack of "
    "Apple developer infrastructure.",
]

RESULTS_5_8 = [
    "Beyond the module-level limits, three systemic issues bound the results. Scalability: in-memory call rooms "
    "and single-instance APIs cap the platform at a small community rather than public scale. Confidentiality: "
    "transport is TLS-encrypted in production and data are isolated per module, but messages are not end-to-end "
    "encrypted, and the AI assistant necessarily sends recent conversation context to an external model — a "
    "trade-off disclosed to users. Assurance: without continuous integration or accessibility testing, quality "
    "rests on process discipline rather than infrastructure. Each is documented in the handoff material with a "
    "remediation.",
]

ETHICS = [
    "Global Village collects personal data: emails, names, birth dates, optional phone numbers and addresses, "
    "precise location, and message and family-record content. Because the software interacts with the public, the "
    "team treated the Privacy Act 1988 (Cth) and the Australian Privacy Principles (OAIC n.d.) as design "
    "constraints. Collection is limited to what each feature needs: the matching API never returns phone numbers "
    "or addresses, nearby-people positions require opt-in and expire within five minutes, and family demonstration "
    "data are fictional. The platform targets adults; minors were a recognised risk — no age verification is "
    "implemented (a documented limitation), and the terms page states the intended audience.",

    "Security practice was OWASP-informed (OWASP Foundation 2021) and followed NIST guidance (Grassi, Garcia & "
    "Fenton 2017): bcrypt hashing, timing-safe one-time codes, rate limiting, lockout, anti-enumeration, token "
    "revocation and production TLS via Caddy; database ports are localhost-bound in development, and deliverables "
    "ship only environment templates, never secrets. Third-party components are used within their terms: Google "
    "Sign-In (verified server-side), QQ Mail over TLS, Google public STUN, and a free GLM endpoint for the "
    "optional AI assistant, disclosed as external processing. All libraries are open-source licensed, and no "
    "proprietary data were accessed. User risks were assessed as low: location features are consent-gated and "
    "short-lived, calls are peer-to-peer and not recorded, and no payments or sensitive categories are handled. "
    "Equity and accessibility were only partially delivered — the interface has not been audited with assistive "
    "technology, which is documented as future work. The main residual risk, misuse of presence signals, is "
    "mitigated by rate limits and expiries but not eliminated.",
]

REFERENCES = [
    "AIHW 2023, Social isolation and loneliness, Australian Institute of Health and Welfare, Canberra, viewed "
    "November 2026, <https://www.aihw.gov.au>.",
    "Australian Government 1988, Privacy Act 1988 (Cth), Federal Register of Legislation, Canberra, viewed "
    "November 2026, <https://www.legislation.gov.au/C1988A000119/latest/text>.",
    "Docker Inc. n.d., Docker documentation, viewed November 2026, <https://docs.docker.com>.",
    "Google n.d., Flutter documentation, viewed November 2026, <https://docs.flutter.dev>.",
    "Google Developers n.d., Google Sign-In for web and Android, viewed November 2026, "
    "<https://developers.google.com/identity>.",
    "Grassi, PA, Garcia, ME & Fenton, JL 2017, Digital identity guidelines: authentication and lifecycle "
    "management, NIST Special Publication 800-63B, National Institute of Standards and Technology, Gaithersburg, "
    "<https://doi.org/10.6028/NIST.SP.800-63b>.",
    "Jones, M, Bradley, J & Sakimura, N 2015, JSON Web Token (JWT), RFC 7519, Internet Engineering Task Force, "
    "<https://www.rfc-editor.org/rfc/rfc7519>.",
    "Meetup Inc. n.d., Meetup: find local groups, events and activities, viewed November 2026, "
    "<https://www.meetup.com>.",
    "Mozilla n.d., WebSocket, MDN Web Docs, viewed November 2026, "
    "<https://developer.mozilla.org/docs/Web/API/WebSocket>.",
    "OAIC n.d., Australian Privacy Principles, Office of the Australian Information Commissioner, Sydney, viewed "
    "November 2026, <https://www.oaic.gov.au/privacy/australian-privacy-principles>.",
    "OWASP Foundation 2021, OWASP Top 10:2021, viewed November 2026, <https://owasp.org/Top10>.",
    "PostgreSQL Global Development Group n.d., PostgreSQL 16 documentation, viewed November 2026, "
    "<https://www.postgresql.org/docs/16>.",
    "Provos, N & Mazières, D 1999, 'A future-adaptable password scheme', Proceedings of the 1999 USENIX Annual "
    "Technical Conference, USENIX Association, Monterey, CA, pp. 81–91.",
    "Tencent n.d., WeChat, viewed November 2026, <https://www.wechat.com>.",
    "W3C 2021, WebRTC 1.0: real-time communication between browsers, W3C Recommendation, viewed November 2026, "
    "<https://www.w3.org/TR/webrtc>.",
    "WHO 2023, WHO launches the Commission on Social Connection, World Health Organization, Geneva, viewed "
    "November 2026, <https://www.who.int/news/item/15-08-2023-who-launches-a-commission-on-social-connection>.",
]

# ----------------------------------------------------------------------------
# 2. REPORT CONTENT — INDIVIDUAL SECTION (Xu Yongqi only, ~1,000 words) ------
# ----------------------------------------------------------------------------

INDIV_OPENING = (
    "This section reports my contribution, self-directed learning and project-management involvement in Global "
    "Village. I was responsible for the chat domain — the Chat microservice and every chat main and sub-page, "
    "including calls — with the percentages below self-assessed against the results in Section 5."
)

INDIV_CONTRIB = [
    "I implemented 100% of the Chat microservice (Aims A2–A3): a Node.js/Express service backed by its own "
    "PostgreSQL 16 database. I designed the schema — a mirrored public profile row per user, friendships with a "
    "unique unordered-pair constraint and a no-self-friendship check, messages with read receipts and voice "
    "columns, and group tables with role and mute state — and wrote the friendship endpoints (request, accept, "
    "decline, remove), the one-to-one message endpoints carrying text, location and base64 voice content within a "
    "5 MB envelope cap, the conversations endpoint that merges one-to-one and group threads with unread counts, "
    "and the group endpoints: create, invite, promote, demote, mute, unmute, remove, leave and disband, all "
    "governed by a server-side role rank (owner above admin above member), making privilege escalation "
    "impossible by construction. Read receipts update a per-conversation last-read timestamp, and the service "
    "upserts both users' public profiles whenever a friend list is fetched, so chats never depend on a direct "
    "Auth database read. I also implemented the AI assistant: a server-sent-events proxy to an OpenAI-compatible "
    "endpoint with a twenty-message rolling context, replies persisted so users can revisit or clear their "
    "history.",

    "The call-signalling WebSocket was my highest-risk component. Every socket authenticates by "
    "validating the login token through the Auth API; a thirty-second heartbeat detects dead clients, a 256 KB "
    "payload cap bounds memory, and one-socket-per-user semantics (a new connection replaces the old with code "
    "4000) keep presence consistent. Signalling is authorised server-side: a one-to-one offer is forwarded only "
    "after re-verifying the friendship, and group actions check membership, so no client can initiate an "
    "unauthorised call. Group rooms live in memory with a roster broadcast, and a departure is fanned out to "
    "everyone remaining.",

    "On the frontend I implemented 100% of the chat main and sub-pages: the conversation list with friend-request "
    "badges and unread state; the 1,854-line shared one-to-one and group conversation page with text, voice "
    "recording and playback, location messages, read receipts, call buttons and the group member panel (promote, "
    "demote, mute, remove); add-friend, find-friends search, friend requests, friend profile and group invite; "
    "and the AI chat page with a typewriter effect. Voice messages are recorded with the record package and "
    "played back with audioplayers, wrapped in a service that hides the web-versus-file difference. I wrote the "
    "two end-to-end WebSocket scripts used in regression and roughly 10% of the demo seeding "
    "(friendships and the demo group), and contributed about 5% of the cross-service integration by adopting the "
    "Auth token contract in Chat.",
]

INDIV_LEARNING = [
    "My largest self-learning effort was WebRTC, studied from first principles: getUserMedia constraints with an "
    "audio-only fallback, peer connections, the offer, answer and ICE model, and the role of STUN. I designed the "
    "group-call topology myself — a full mesh in which each participant holds one peer connection to every other "
    "participant and joiners always send the offers, a rule that structurally prevents offer glare — while "
    "accepting the quadratic cost analysed in Section 5.3. I also studied the flutter_webrtc package's divergences "
    "between web and Android, which produced the platform wrappers and the fallback path. I learned production "
    "WebSocket engineering: heartbeats, client reconnection with exponential backoff from one to thirty seconds, "
    "and payload limits. I learned server-sent events as a lighter channel for streaming AI replies, and how to "
    "proxy a third-party endpoint without exposing its credentials to the browser.",

    "On the Flutter side, I learned to manage global call state through ChangeNotifier singletons and a root "
    "navigator key, so an incoming call can take over the screen from any page; and designing the schema taught me "
    "practical PostgreSQL: unordered-pair uniqueness, partial indexes and read-receipt updates. None of this was "
    "covered in coursework — each item came from specifications, source code and experiments, then hardened in "
    "the module's tests and the two end-to-end scripts.",
]

INDIV_PM = [
    "I attended every weekly team meeting and supervisor review, and presented live demonstrations "
    "rather than slides on three occasions: a two-window one-to-one call, a three-window group call exercising "
    "mute and removal, and the AI assistant. The mute demonstration earned the most valuable feedback of the "
    "project — my first implementation muted members only in the interface, and review made clear that moderation "
    "must be enforced at the API; I rebuilt it server-side within the week and added regression cases so it could "
    "not regress silently. Supervisor feedback helped twice more: a request to demonstrate a call behind a strict "
    "network shaped the fallback documentation, and a question about reconnect behaviour led to the backoff "
    "curve.",

    "I believe I participated with ideas rather than quietly listening: the group-call joiner-offer rule and the "
    "decision to reuse one WebSocket for both presence and signalling were proposals I brought to the team and "
    "defended with prototypes. The team's merge protocol (documented review, additive migrations only, full "
    "regression before acceptance) shaped how I delivered: backend, pages and tests were complete ahead of the "
    "integration dates, which mattered because the profile and family modules both consume my conversation and "
    "member APIs; my merges passed the full suite on their first run. I coordinated directly with Wang on the "
    "token-validation contract, with Ying on WebSocket transport through the Azure reverse proxy, where TLS "
    "required the wss scheme, and with Huang when profile entries began appearing in chat headers. I estimate my "
    "overall share of the delivered system at roughly 30%: 100% of the chat backend, chat interfaces and call "
    "stack, about 10% of the demo seeding, and the integration work above. On reflection, I would raise the "
    "selective-forwarding option for group calls earlier: the mesh was defensible for five-to-eight person calls, "
    "but I underestimated how quickly browsers degrade beyond that, and the limitation is documented for the "
    "next iteration.",
]

# ----------------------------------------------------------------------------
# 3. WORD COUNT --------------------------------------------------------------
# ----------------------------------------------------------------------------

def wc(*blocks):
    n = 0
    for b in blocks:
        if isinstance(b, str):
            n += len(b.split())
        elif isinstance(b, (list, tuple)):
            for item in b:
                if isinstance(item, str):
                    n += len(item.split())
                else:
                    n += len(item[1].split()) if isinstance(item, tuple) else 0
    return n

aims_words = wc(AIMS_INTRO) + sum(wc(h) + wc(t) for h, t in AIMS)
bg_words = wc(BACKGROUND)
m_words = wc(METHODS)
res_words = (wc(RESULTS_5_1) + wc(RESULTS_5_2) + wc(RESULTS_5_3) + wc(RESULTS_5_4)
             + wc(RESULTS_5_5) + wc(RESULTS_5_6) + wc(RESULTS_5_7) + wc(RESULTS_5_8))
eth_words = wc(ETHICS)
group_words = bg_words + aims_words + m_words + res_words + eth_words
ind_words = wc(INDIV_OPENING) + wc(INDIV_CONTRIB) + wc(INDIV_LEARNING) + wc(INDIV_PM)

print("Background: %d | Aims: %d | Methods: %d | Results: %d | Ethics: %d" %
      (bg_words, aims_words, m_words, res_words, eth_words))
print("GROUP section total: %d" % group_words)
print("INDIVIDUAL section total (Xu Yongqi): %d" % ind_words)
print("Combined (group + individual): %d" % (group_words + ind_words))
assert group_words + ind_words <= 3500, "combined length must not exceed 3500 words"

# ----------------------------------------------------------------------------
# 4. FIGURE 1 (architecture diagram, drawn with Pillow) ----------------------
# ----------------------------------------------------------------------------

def font(name, size):
    try:
        return ImageFont.truetype(name, size)
    except OSError:
        return ImageFont.load_default()

def make_figure(path):
    import math
    W, H = 1560, 800
    img = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(img)
    f_title = font("arialbd.ttf", 21)
    f_line = font("arial.ttf", 17)
    f_note = font("arialbd.ttf", 16)

    fill = (232, 240, 248)
    edge = (53, 80, 107)
    ink = (31, 42, 58)

    def box(x0, y0, x1, y1, lines, title_idx=0):
        d.rectangle([x0, y0, x1, y1], fill=fill, outline=edge, width=2)
        n = len(lines)
        lh = 30
        total = n * lh
        y = y0 + ((y1 - y0) - total) / 2
        for i, ln in enumerate(lines):
            f = f_title if i == title_idx else f_line
            w = d.textlength(ln, font=f)
            d.text((x0 + (x1 - x0) / 2 - w / 2, y), ln, font=f, fill=ink)
            y += lh

    def arrow(points, color=(70, 70, 70), width=3, head=12):
        for i in range(len(points) - 1):
            d.line([points[i], points[i + 1]], fill=color, width=width)
        (x0, y0), (x1, y1) = points[-2], points[-1]
        ang = math.atan2(y1 - y0, x1 - x0)
        a1 = (x1 - head * math.cos(ang - 0.45), y1 - head * math.sin(ang - 0.45))
        a2 = (x1 - head * math.cos(ang + 0.45), y1 - head * math.sin(ang + 0.45))
        d.polygon([(x1, y1), a1, a2], fill=color)

    def dashed_arrow(points, color=(31, 92, 153), width=3, dash=12, gap=7):
        (x0, y0), (x1, y1) = points[-2], points[-1]
        ang = math.atan2(y1 - y0, x1 - x0)
        a1 = (x1 - 12 * math.cos(ang - 0.45), y1 - 12 * math.sin(ang - 0.45))
        a2 = (x1 - 12 * math.cos(ang + 0.45), y1 - 12 * math.sin(ang + 0.45))
        d.polygon([(x1, y1), a1, a2], fill=color)
        for i in range(len(points) - 1):
            (x0, y0), (x1, y1) = points[i], points[i + 1]
            dist = math.hypot(x1 - x0, y1 - y0)
            if dist == 0:
                continue
            ux, uy = (x1 - x0) / dist, (y1 - y0) / dist
            t = 0.0
            while t < dist:
                seg_end = min(t + dash, dist)
                d.line([(x0 + ux * t, y0 + uy * t), (x0 + ux * seg_end, y0 + uy * seg_end)],
                       fill=color, width=width)
                t = seg_end + gap

    box(330, 30, 1230, 110,
        ["Flutter client (Dart)",
         "Web app on :7357  ·  Android APK (universal / arm64 / arm32)"])
    box(180, 190, 1380, 270,
        ["Public gateway — nginx (SPA hosting + /api/* reverse proxy)",
         "Caddy automatic HTTPS in the Azure deployment"])
    arrow([(780, 110), (780, 190)])

    api_x = [(78, 378), (446, 746), (814, 1114), (1182, 1482)]
    boxes = [
        ["Auth API  :3002", "Express · bcrypt · JWT", "PostgreSQL 16 (:5434)"],
        ["Chat API  :3004", "Express · ws · SSE", "PostgreSQL 16 (:5435)"],
        ["Community API  :3000", "Express · geo queries", "PostgreSQL 16 (:5433)"],
        ["Family API  :3003", "node:http · zero-dep", "SQLite (WAL mode)"],
    ]
    for (x0, x1), lines in zip(api_x, boxes):
        box(x0, 380, x1, 620, lines)

    centers = [(x0 + x1) // 2 for x0, x1 in api_x]
    for cx in centers:
        arrow([(cx, 270), (cx, 380)])

    bus_y = 690
    for src in centers[1:]:
        dashed_arrow([(src, 620), (src, bus_y), (centers[0], bus_y), (centers[0], 620)])
    note = "JWT validation — every downstream request is verified against the Auth API (/auth/me)"
    w = d.textlength(note, font=f_note)
    d.text(((W - w) / 2, bus_y + 14), note, font=f_note, fill=(31, 92, 153))

    img.save(path, "PNG")

FIG_PATH = os.path.join(tempfile.gettempdir(), "gv_fig1_architecture.png")
make_figure(FIG_PATH)

# ----------------------------------------------------------------------------
# 5. BUILD THE DOCX -----------------------------------------------------------
# ----------------------------------------------------------------------------

doc = Document()

normal = doc.styles["Normal"]
normal.font.name = "Times New Roman"
normal.font.size = Pt(11)
normal.paragraph_format.space_after = Pt(6)
normal.paragraph_format.line_spacing = 1.15

for name, size in (("Heading 1", 14), ("Heading 2", 12)):
    st = doc.styles[name]
    st.font.name = "Times New Roman"
    st.font.size = Pt(size)
    st.font.bold = True
    st.font.color.rgb = RGBColor(0, 0, 0)

def para(text="", align=WD_ALIGN_PARAGRAPH.JUSTIFY, bold=False, italic=False,
         size=None, space_after=6):
    p = doc.add_paragraph()
    p.alignment = align
    p.paragraph_format.space_after = Pt(space_after)
    if text:
        r = p.add_run(text)
        r.bold = bold
        r.italic = italic
        if size:
            r.font.size = Pt(size)
    return p

def h1(text):
    p = doc.add_heading(text, level=1)
    for r in p.runs:
        r.font.name = "Times New Roman"
    return p

def h2(text):
    p = doc.add_heading(text, level=2)
    for r in p.runs:
        r.font.name = "Times New Roman"
    return p

def caption(text):
    return para(text, align=WD_ALIGN_PARAGRAPH.CENTER, italic=True, size=10, space_after=10)

def shade(cell, hexcolor="DCE6F1"):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hexcolor)
    tcPr.append(shd)

def add_table(headers, rows, widths=None):
    t = doc.add_table(rows=1 + len(rows), cols=len(headers))
    t.style = "Table Grid"
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    for j, htext in enumerate(headers):
        cell = t.cell(0, j)
        cell.text = htext
        shade(cell)
        for p in cell.paragraphs:
            for r in p.runs:
                r.bold = True
    for i, row in enumerate(rows, start=1):
        for j, val in enumerate(row):
            t.cell(i, j).text = val
    if widths:
        for j, w in enumerate(widths):
            for i in range(len(rows) + 1):
                t.cell(i, j).width = Cm(w)
    return t

def page_number_footer(section):
    footer = section.footer
    footer.is_linked_to_previous = False
    p = footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run()
    fld1 = OxmlElement("w:fldChar"); fld1.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText"); instr.set(qn("xml:space"), "preserve"); instr.text = "PAGE"
    fld2 = OxmlElement("w:fldChar"); fld2.set(qn("w:fldCharType"), "end")
    run._r.append(fld1); run._r.append(instr); run._r.append(fld2)

# ---- title page (section 1)
sec1 = doc.sections[0]
for line in (
    "COMP3851B — Computing and Information Systems Work Integrated Learning",
    "School of Information and Physical Sciences, The University of Newcastle",
):
    para(line, align=WD_ALIGN_PARAGRAPH.CENTER, size=12, space_after=2)

para("", space_after=18)
para("FINAL REPORT — GROUP PROJECT", align=WD_ALIGN_PARAGRAPH.CENTER, bold=True, size=22, space_after=18)
para("Project title:", align=WD_ALIGN_PARAGRAPH.CENTER, size=12, space_after=2)
para(TITLE, align=WD_ALIGN_PARAGRAPH.CENTER, bold=True, size=14, space_after=24)

para("Students:", align=WD_ALIGN_PARAGRAPH.CENTER, bold=True, size=12, space_after=4)
for name in ("Wang Zuzan", "Xu Yongqi", "Ying Haozhe", "Dai Zihong", "Huang Zhiyong"):
    para("%s — Student number: [__________]" % name,
         align=WD_ALIGN_PARAGRAPH.CENTER, size=12, space_after=2)

para("", space_after=14)
para("Supervisor: [Supervisor name]", align=WD_ALIGN_PARAGRAPH.CENTER, size=12, space_after=2)
para("Industry / research group: Work Integrated Learning placement, "
     "School of Information and Physical Sciences, University of Newcastle",
     align=WD_ALIGN_PARAGRAPH.CENTER, size=12, space_after=2)
para("Submission date: November 2026 (Week 12)", align=WD_ALIGN_PARAGRAPH.CENTER, size=12, space_after=14)

para("Group section: %s words  ·  Individual section (Xu Yongqi): %s words  ·  Combined: %s words "
     "(within the 3,500-word group-project limit; title page, headings, tables, figures "
     "and references excluded from counts)"
     % (group_words, ind_words, group_words + ind_words),
     align=WD_ALIGN_PARAGRAPH.CENTER, italic=True, size=10)

# ---- section 2: the report body
sec2 = doc.add_section(WD_SECTION.NEW_PAGE)
sec2.header.is_linked_to_previous = False
hp = sec2.header.paragraphs[0]
hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
hr = hp.add_run("COMP3851B Final Report — Global Village")
hr.italic = True
hr.font.size = Pt(9)
page_number_footer(sec2)

h1("Group Section")

h2("1. Project Title")
para(TITLE, bold=True)

h2("2. Background")
for p in BACKGROUND:
    para(p)

h2("3. Aims")
para(AIMS_INTRO)
for head, text in AIMS:
    p = para()
    r1 = p.add_run(head + " ")
    r1.bold = True
    p.add_run(text)
caption("Table 1: Aims, completion status and primary deliverables.")
add_table(
    ["Aim", "Status", "Primary deliverable"],
    [
        ["A1 Secure identity platform", "Completed", "Auth API, login/registration/recovery pages, 75 API tests"],
        ["A2 Messaging and social graph", "Completed", "Chat API, chat list and conversation pages"],
        ["A3 Real-time calls", "Completed", "WebRTC 1:1 and group calls, call pages"],
        ["A4 Community engagement", "Completed", "Community API, activities, map, nearby people"],
        ["A5 Family and tree connections", "Completed (one sub-item ongoing)", "Family API, family and tree pages, 45 API tests"],
        ["A6 Profile and matching", "Completed", "Profile API, profile page with matching views"],
        ["A7 Deployment and QA", "Mostly completed", "Docker stacks, Azure HTTPS deployment, Android packages, 220+ tests"],
    ],
    widths=[5.5, 4.0, 7.0],
)

h2("4. Methods and activities")
for p in METHODS:
    para(p)

h2("5. Results")
h2("5.1 Delivered system")
for p in RESULTS_5_1:
    para(p)
doc.add_picture(FIG_PATH, width=Cm(16))
doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
caption("Figure 1: Global Village system architecture — one Flutter client, a public gateway, four "
        "microservices each owning its database; every downstream request is validated against the Auth API.")
caption("Table 2: Delivered components.")
add_table(
    ["Component", "Responsibility", "Port", "Technology and database"],
    [
        ["Flutter client", "All user-facing features (web and Android)", "7357 (web)", "Flutter 3.44 / Dart"],
        ["Public gateway", "SPA hosting and /api/* reverse proxy; TLS termination on Azure", "7357", "nginx 1.27 · Caddy 2"],
        ["Auth API", "Registration, login, Google Sign-In, recovery, profiles, user search, matching", "3002", "Node.js / Express · PostgreSQL 16 (:5434)"],
        ["Chat API", "Friends, 1:1 and group messages, moderation, call signalling, AI assistant", "3004", "Node.js / Express · ws · PostgreSQL 16 (:5435)"],
        ["Community API", "Activities, attendance, geo discovery, nearby people", "3000", "Node.js / Express · PostgreSQL 16 (:5433)"],
        ["Family API", "Families, records, family tree, identity tags", "3003", "node:http (zero-dep) · SQLite WAL"],
    ],
    widths=[3.2, 6.0, 2.0, 5.3],
)

h2("5.2 Identity and security (Aim A1)")
for p in RESULTS_5_2:
    para(p)

h2("5.3 Communication and calls (Aims A2–A3)")
for p in RESULTS_5_3:
    para(p)

h2("5.4 Community (Aim A4)")
for p in RESULTS_5_4:
    para(p)

h2("5.5 Family (Aim A5)")
for p in RESULTS_5_5:
    para(p)

h2("5.6 Profile and matching (Aim A6)")
for p in RESULTS_5_6:
    para(p)

h2("5.7 Deployment and quality assurance (Aim A7)")
for p in RESULTS_5_7:
    para(p)
caption("Table 3: Automated verification on the delivered build.")
add_table(
    ["Suite", "Tooling", "Cases", "Result"],
    [
        ["Flutter widget and unit tests", "flutter test (Flutter 3.44.6)", "105", "105/105 pass"],
        ["Auth API tests", "node:test + PGlite + real PostgreSQL integration", "75", "75/75 pass"],
        ["Family API tests", "node:test", "45", "45/45 pass"],
        ["Call-signalling end-to-end scripts", "Node WebSocket clients", "2 scripts", "Pass (1:1 and group flows)"],
        ["Static analysis", "flutter analyze", "—", "0 issues, 0 warnings, 0 infos"],
    ],
    widths=[5.0, 5.5, 2.0, 4.0],
)

h2("5.8 Systemic limitations")
for p in RESULTS_5_8:
    para(p)

h2("6. Ethics considerations")
for p in ETHICS:
    para(p)

h2("7. References")
for ref in REFERENCES:
    p = para(ref, align=WD_ALIGN_PARAGRAPH.LEFT)
    p.paragraph_format.left_indent = Cm(0.75)
    p.paragraph_format.first_line_indent = Cm(-0.75)

# ---- individual section: Xu Yongqi only (new page)
doc.add_page_break()
h1("Individual Section — Xu Yongqi: Individual Contribution, Self-Learning and Project Management")
para("Xu Yongqi — Student number: [__________]", italic=True)
para(INDIV_OPENING)
h2("Individual contribution")
for p in INDIV_CONTRIB:
    para(p)
h2("Self-directed learning")
for p in INDIV_LEARNING:
    para(p)
h2("Project management and teamwork")
for p in INDIV_PM:
    para(p)

doc.save(OUT_DOCX)
print("Saved:", OUT_DOCX)
