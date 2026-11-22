# -*- coding: utf-8 -*-
"""Build the GlobalVillage group final report (.docx)."""
import re
from docx import Document
from docx.shared import Pt, RGBColor, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

BLUE = RGBColor(0x1F, 0x4E, 0x79)
DARK = RGBColor(0x26, 0x26, 0x26)

# ----------------------------------------------------------------------------
# CONTENT (group section)
# ----------------------------------------------------------------------------

TITLE = ("Global Village: A Cross-Platform Community Application with "
         "Microservice Backends for Authentication, Chat, Community, Family "
         "and Profile Services")

MEMBERS = [
    ("WANGZUZAN", "[Student Number]", "Authentication, registration and login"),
    ("XUYONGQI", "[Student Number]", "Chat main page and sub-pages"),
    ("YINGHAOZHE", "[Student Number]", "Community module"),
    ("DAIZIHONG", "[Student Number]", "Family module"),
    ("HUANGZHIYONG", "[Student Number]", "Profile module"),
]

BACKGROUND = [
("This project was undertaken within the University of Newcastle COMP3851A/B "
 "Work Integrated Learning (WIL) program, a two-semester capstone in which "
 "student teams deliver an industry-style software product. A team of five "
 "students designed, built, integrated and deployed Global Village, a "
 "cross-platform community application, following professional practice: "
 "module ownership, staged merge checkpoints, handoff packages with "
 "verification manifests, peer code review, automated regression suites and "
 "production-style deployment."),
("Modern migrant and student communities, including the more than seven "
 "million residents of Australia born overseas [1], increasingly maintain "
 "their social lives through fragmented tools. Day-to-day messaging happens "
 "in one application, community events are advertised in another, and family "
 "coordination is squeezed into a shared group chat. Information is "
 "scattered, privacy is delegated to advertising-driven platforms, and no "
 "single product serves the combined needs of community engagement and "
 "private family coordination."),
("Two dominant products partially address this problem. WeChat [2] is a "
 "\u201csuper-app\u201d combining messaging, group management and social feeds, but "
 "it is a closed ecosystem: it cannot be self-hosted, its community features "
 "are not modular, and organisations have no control over data residency or "
 "deployment. Facebook Groups [3] supports communities and events at scale, "
 "but its business model is built on advertising and extensive data "
 "collection, and neither product offers structured family coordination such "
 "as a consent-based family tree."),
("Global Village differs in three ways. First, it is self-hostable: every "
 "component runs locally or on an organisation's own cloud (demonstrated on "
 "Azure), so data remains under the operator's control. Second, it is "
 "modular: authentication, chat, community, family and profile functions are "
 "independent microservices that can be deployed, tested and upgraded "
 "separately. Third, it is privacy-conscious by design: passwords are hashed "
 "with bcrypt, sessions are invalidated on password reset, real-time call "
 "media flows peer-to-peer via WebRTC rather than through a proprietary "
 "relay, and cross-group family links are created only with the explicit, "
 "unanimous consent of every affected administrator."),
("The motivation for the project is therefore twofold: to give communities a "
 "single, integrated and trustworthy platform, and to give the team realistic "
 "industry experience by requiring professional-grade engineering, including "
 "containerised deployment, test automation, security hardening and staged "
 "releases, rather than a toy application. Today the professional community "
 "addresses this need with manual combinations of generic tools (a group "
 "chat for family, an event page for the community, a shared list for "
 "activities). Global Village consolidates these functions into one "
 "deployable product built on widely adopted open technologies: Flutter for "
 "cross-platform delivery, Node.js microservices with PostgreSQL and SQLite "
 "storage, Docker Compose orchestration, WebRTC for real-time communication, "
 "and an nginx gateway with automatic HTTPS in production."),
("Within the team, each member owned one module end-to-end (frontend, "
 "backend and database), as summarised in Table 1. This ownership model "
 "shaped the engineering process, the results reported in Section 4 and the "
 "individual accounts in Section 7."),
]

TABLE1_HEAD = ["Member", "Owned module", "Deliverables owned end-to-end"]
TABLE1_ROWS = [
    ["WANGZUZAN", "Authentication", "Auth microservice, PostgreSQL schema, Docker stack, registration/login/password-recovery UI"],
    ["XUYONGQI", "Chat", "Chat UI (main page and sub-pages), chat microservice, WebSocket signalling, WebRTC calls, chat database"],
    ["YINGHAOZHE", "Community", "Community UI (feed, map, nearby people), community microservice, geo queries, database"],
    ["DAIZIHONG", "Family", "Family UI (groups and family tree), zero-dependency family microservice, SQLite store"],
    ["HUANGZHIYONG", "Profile", "Profile UI, profile model and state, interest matching and recommendations UI"],
]

AIMS = [
("The aims below cover the full two-semester period. Every core functional "
 "aim was completed and verified; two carry ongoing maintenance, as "
 "indicated. Each aim is attached to concrete deliverables."),
("1. Deliver a secure, cross-platform community application. Build a "
 "Flutter application for web and Android providing account registration, "
 "login, a profile, and a tabbed social interface. (Completed: the app runs "
 "in Chrome and on Android devices via packaged APKs.)"),
("2. Implement a modular microservice backend. Provide independent "
 "authentication, chat, community and family services, each with its own "
 "database, orchestrated by Docker Compose behind a single gateway. "
 "(Completed: four services start with one-click scripts or a full "
 "production stack.)"),
("3. Enable real-time communication. Provide friend requests, one-to-one "
 "and group text and voice messaging, and WebRTC voice/video calls for "
 "individuals and groups. (Completed.)"),
("4. Provide community engagement tools. Provide an activity feed with "
 "attendance, nearby-people discovery with a map view, and check-ins. "
 "(Completed.)"),
("5. Provide a family module with a consent-based family tree. Support "
 "multiple family groups per user, and a cross-group tree requiring "
 "explicit, unanimous administrator approval. (Completed.)"),
("6. Provide profile management and interest matching. Provide validated "
 "profile editing plus interest-based match and recommendation tabs. "
 "(Completed; email changes and avatar upload remain future work.)"),
("7. Deliver deployable releases. Provide one-click local deployment, a "
 "public demonstration tunnel, an Azure production stack with TLS, and "
 "Android packages. (Completed; the temporary public URL requires "
 "maintenance, so this aim is completed with ongoing operational work.)"),
]

METHODS = [
("The team used an agile, ownership-based method: each member owned one "
 "module end-to-end (Table 1), met weekly as a group and regularly with "
 "the supervisor. Integration occurred at staged merge checkpoints "
 "(September baseline, October team merge, October family-tree update, "
 "November profile hardening), where handoff packages, manifests and "
 "test reports were peer-reviewed."),
("Frontend methods (Aims 1, 3, 4, 5, 6). A single Flutter codebase targets "
 "web and Android. State is managed with StatefulWidgets and ValueNotifiers; "
 "REST calls use package:http; call signalling uses web_socket_channel; "
 "calls use flutter_webrtc; the community map uses flutter_map with "
 "OpenStreetMap tiles and geolocator for device location."),
("Backend methods (Aim 2). The authentication, chat and community services "
 "are Node.js/Express applications backed by dedicated PostgreSQL instances. "
 "The family service deliberately uses zero-dependency Node (node:http with "
 "node:sqlite) to demonstrate a lightweight, portable design. JWT tokens "
 "gate every API, and the family service delegates token verification to "
 "the authentication service."),
("Security methods (Aims 1, 7). Passwords are hashed with bcrypt; tokens "
 "carry a session version that is invalidated on password reset; sensitive "
 "endpoints are rate-limited; verification and reset credentials are "
 "single-use and time-boxed; secrets are supplied through environment "
 "files excluded from the repository [14], [15]."),
("Real-time communication methods (Aim 3). Call signalling (offer/answer and "
 "ICE candidates) rides an authenticated WebSocket with heartbeat and "
 "exponential reconnection backoff; group calls use a full-mesh WebRTC "
 "topology over public STUN servers [10]."),
("Deployment and self-learning (Aim 7). Docker Compose orchestrates every "
 "stack; nginx serves the built web app and proxies the four APIs; Caddy "
 "adds automatic TLS on Azure. Self-learning included Flutter web "
 "deployment, WebRTC mesh design, Docker networking, node:sqlite and "
 "location-permission handling. Testing was continuous: 105 Flutter tests "
 "and roughly 70 backend tests were maintained across sprints."),
]

RESULTS_41 = [
("The delivered system fully realises Aims 1\u20136 and substantially realises "
 "Aim 7. It comprises five functional modules served by four independent "
 "microservices, approximately 24,000 lines of Dart (of which about 2,800 "
 "are automated tests) and roughly 6,000 lines of server-side JavaScript. "
 "The full automated suite passes: 105 of 105 Flutter tests, 35 "
 "authentication unit/local-SMTP tests plus a live PostgreSQL integration "
 "test, and 35 family backend tests; static analysis reports zero issues "
 "and the production web build succeeds. Table 2 summarises the deployed "
 "services and Table 3 the automated coverage per module. Each module's "
 "results are described below against the aims; individual ownership is "
 "detailed in Section 7. Functional requirements traced from the aims were "
 "demonstrated in scripted end-to-end scenarios: registration to first "
 "message, friend request to conversation, a three-participant group call, "
 "activity join and check-in, family-tree approval across two groups, and "
 "profile editing with logout isolation."),
]

TABLE2_HEAD = ["Service", "Port", "Storage", "Role"]
TABLE2_ROWS = [
    ["Community API", "3000", "PostgreSQL (5433)", "Activities, attendance, nearby people, check-ins"],
    ["Auth API", "3002", "PostgreSQL (5434) + Adminer (8082)", "Registration, login, recovery, user search, matching candidates"],
    ["Family API", "3003", "SQLite volume", "Family groups, activities, consent-based family tree"],
    ["Chat API", "3004", "PostgreSQL (5435)", "Friends, messages, groups, AI proxy, WebSocket signalling (/ws)"],
    ["Flutter Web", "7357", "\u2014", "nginx gateway hosting the built app and proxying all APIs"],
]

TABLE3_HEAD = ["Module", "Automated coverage", "Outcome"]
TABLE3_ROWS = [
    ["Authentication", "35 unit/local-SMTP tests + 1 PostgreSQL integration test", "All pass"],
    ["Chat", "Session-state and storage suites within the Flutter suite", "All pass"],
    ["Community", "Nearby-map and nearby-people service suites", "All pass"],
    ["Family", "34 Flutter tests + 35 backend tests", "All pass"],
    ["Profile", "Model-mapping and page-state suites", "All pass"],
    ["Whole app", "flutter test (18 files) + flutter analyze", "105/105; zero issues"],
]

RESULTS_42 = [
("The authentication module (Aim 1) delivers the complete account lifecycle. "
 "Registration collects an email, username and password and verifies the "
 "email with a time-boxed six-digit SMTP code, with resend support. Login "
 "issues JWTs that carry a session version, so changing a password or "
 "resetting it invalidates every outstanding token; protected endpoints "
 "reject stale tokens immediately. Google Sign-In verifies Google ID tokens "
 "server-side and links accounts by a google_sub identifier, supporting "
 "Google-only accounts. Password recovery offers two paths: an emailed "
 "verification code, or a security-question flow in which five failed "
 "answers trigger a fifteen-minute lockout and successful verification "
 "yields a single-use, five-minute reset credential. Case-insensitive "
 "uniqueness is enforced with lower(email)/lower(username) indexes, and "
 "hashing uses bcrypt. The service also exposes the user-search and "
 "match-candidate endpoints consumed by the chat and profile modules, "
 "making authentication a shared foundation (Section 7.1)."),
]

RESULTS_43 = [
("The chat module (Aim 3) provides the full social-communication loop. "
 "Users find friends by email, username or name; requests are sent, "
 "accepted or declined, with live badge counts on the home page. "
 "Conversations persist one-to-one text and voice messages in PostgreSQL "
 "with read-state tracking. Group chats support an owner/administrator "
 "hierarchy: owners appoint or demote administrators, mute or remove any "
 "member, and cannot be managed themselves; muted members see an inline "
 "restriction instead of silently failing. Calls are WebRTC-based: one-to-"
 "one calls present a full-screen incoming interface with accept/decline, "
 "and group calls use a full-mesh topology in which any member can start a "
 "call, online members receive an invitation, and late joiners see an "
 "\u201conngoing call\u201d banner to join. Signalling runs over an authenticated "
 "WebSocket with heartbeat and exponential reconnect backoff. An AI "
 "assistant tab proxies conversations to a hosted GLM-4-flash model and "
 "stores history server-side (Section 7.2)."),
]

RESULTS_44 = [
("The community module (Aim 4) centres on location. The feed lists "
 "activities within 500 metres, and users create, edit, join or delete "
 "activities with an attendee list. Nearby-people discovery offers 10, 20, "
 "50 and 100 metre selectors that stay synchronised with map zoom, drawing "
 "a range circle on an OpenStreetMap view; the server caps discovery "
 "queries at a 100-metre radius, 100 candidates and 10 returned users, and "
 "range switching filters the returned set client-side so it costs no "
 "additional database load. Location sharing is opt-in through device "
 "permissions, and check-ins record presence at activities. The interface "
 "follows a consistent blue-and-white visual system shared across the "
 "feed, map, list and activity form (Section 7.3)."),
]

RESULTS_45 = [
("The family module (Aim 5) extends beyond a single group. Users may belong "
 "to multiple family groups, joining with a real name and family role after "
 "previewing the target group, and may nominate a primary group. Groups "
 "support activities, tasks, notes and manual daily check-ins, plus member "
 "management, role changes, invite codes and a combined notification feed. "
 "The family tree connects separate groups by design rather than "
 "implicitly: a requesting group shares a connection code, the target "
 "group previews the request with a relationship label, and the link is "
 "created only after every affected group's administrator explicitly "
 "approves. Requests can be rejected or cancelled and expire after seven "
 "days; role, code or topology changes invalidate affected pending "
 "requests. Administrators can disconnect their group's links and owners "
 "can leave the tree. A full-screen canvas renders the connected component "
 "with drag, pinch-zoom and \u201cshow all\u201d navigation, capped at 50 groups per "
 "component. Approval and disconnection are transactional in SQLite, and "
 "connections grant no access to another family's private records "
 "(Section 7.4)."),
]

RESULTS_46 = [
("The profile module (Aim 6) implements an account-safe, server-first edit "
 "workflow. Fields cleared on the server genuinely clear locally, the "
 "placeholder demo identity was removed so no fabricated profile appears "
 "before load, and load/error/retry states block saving stale placeholders "
 "while offline. Email is read-only because it anchors login identity. "
 "Saving is duplicate-submit protected, validated (username format, phone "
 "format, optional birth date) and applied only after the server accepts. "
 "Keep-alive tabs preserve unsaved edits across navigation, and logout "
 "asks for confirmation and resets both profile and chat-session state to "
 "prevent account-to-account leakage. Interest Match and Recommended tabs "
 "load candidates lazily, filter zero-percent matches, cache results by "
 "identity and use Google photo URLs for avatars. The change reduced "
 "profile_page.dart from about 1,458 to 1,072 lines by extracting match "
 "widgets, with new model and page-state tests (Section 7.5)."),
]

RESULTS_47 = [
("Deployment (Aim 7) works at three levels. Locally, one double-click "
 "script builds and starts all four backend stacks, seeds demo accounts, "
 "friendships and a demo group, and serves the web app through nginx on "
 "port 7357; a portable ZIP distribution proved robust on Chinese-named "
 "and spaced folder paths. Publicly, a Cloudflare Quick Tunnel exposes the "
 "same stack under a temporary HTTPS URL, with databases kept off the "
 "tunnel. For production, an Azure Compose stack adds Caddy automatic TLS "
 "on ports 80/443. Android packages ship as universal (92 MB), arm64 "
 "(33 MB) and arm32 (25 MB) APKs with a LAN server-address setting and a "
 "firewall helper script for phone access."),
]

RESULTS_48 = [
("Critical analysis. The results satisfy Aims 1\u20136 in full and Aim 7 with "
 "caveats, but the design has known limitations. Full-mesh WebRTC calls "
 "create one peer connection per participant pair, so group calls scale "
 "well only to roughly four to six active participants before bandwidth "
 "and encoding load degrade; there is also no TURN fallback, so clients "
 "behind symmetric NATs may fail to connect (a limit on Aim 3). The family "
 "service's SQLite is a deliberate trade-off: a single-writer embedded "
 "database suits family-scale workloads and keeps the service zero-"
 "dependency, but it diverges from the PostgreSQL pattern of the other "
 "services and complicates operational consistency (Aim 2). Profile matching "
 "caps candidates at 200 per request with no pagination, email edits await "
 "a backend verification endpoint, and avatars support Google URLs only "
 "(Aim 6). The public demo URL changes on every restart, so OAuth origins "
 "must be re-registered per session, and Google login was not verified on "
 "the public domain (Aim 7). No iOS package exists because it requires "
 "Apple tooling, and family-tree updates currently require a manual "
 "refresh. Finally, validation relied on automated suites plus scripted "
 "manual scenarios (login, calls, tree approval, portable restart "
 "persistence); no load testing or external user trials were performed, "
 "which limits the evidence about behaviour at scale. None of these "
 "limitations undermines the completed aims, but they define the roadmap "
 "for the next iteration."),
]

ETHICS = [
("Global Village collects identity data (email, username, name, phone), "
 "message content, opt-in location and family relationships, so the "
 "Australian Privacy Act 1988 and its Australian Privacy Principles [13] "
 "were adopted as the guiding framework: data is collected only for declared "
 "functions, stored on infrastructure the operator controls, and never "
 "sold or used for advertising. Because the software interacts with people "
 "and may be reachable by the public, consent is engineered rather than "
 "assumed. The family tree is the clearest example: a cross-group link "
 "requires a connection code, a visible preview, explicit consent and the "
 "unanimous approval of every affected administrator, and it grants no "
 "access to private records. The app is not directed at minors and uses "
 "adult test accounts only; an explicit age declaration remains future "
 "work, and administrative mute/removal tools mitigate misuse such as "
 "harassment in group chats."),
("Security planning follows the ASD Information Security Manual [15] and "
 "OWASP guidance [14]: bcrypt password hashing aligned with NIST SP 800-63B "
 "[12], JWTs invalidated on password reset, rate limiting on sensitive "
 "endpoints, single-use time-boxed recovery credentials with lockouts, "
 "authenticated WebSocket connections, HTTPS via Let's Encrypt in "
 "production, and secrets held in environment files excluded from the "
 "repository. Third-party use is disclosed: Google Sign-In handles "
 "credentials via OAuth, and AI chats are proxied to a hosted GLM-4-flash "
 "model and labelled as an AI feature in-app; public STUN servers see "
 "participant IP addresses during calls. Location features are opt-in and "
 "radius-bounded. The software poses no personal-injury or financial risk, "
 "and equity was considered: it runs free in a browser, ships a 25 MB "
 "package for older phones, and an English-only interface is noted as an "
 "accessibility limitation."),
]

REFERENCES = [
"[1] Australian Bureau of Statistics, \u201cCultural diversity: 2021 Census,\u201d ABS, Canberra, 2022. [Online]. Available: https://www.abs.gov.au/statistics/people/people-and-communities/cultural-diversity-census/2021-census",
"[2] Tencent Holdings Ltd., \u201cWeChat,\u201d 2026. [Online]. Available: https://www.wechat.com",
"[3] Meta Platforms Inc., \u201cFacebook Groups,\u201d 2026. [Online]. Available: https://www.facebook.com/groups",
"[4] Google LLC, \u201cFlutter documentation,\u201d 2026. [Online]. Available: https://docs.flutter.dev",
"[5] Docker Inc., \u201cDocker Compose documentation,\u201d 2026. [Online]. Available: https://docs.docker.com/compose/",
"[6] PostgreSQL Global Development Group, \u201cPostgreSQL 16 documentation,\u201d 2026. [Online]. Available: https://www.postgresql.org/docs/",
"[7] M. Jones, J. Bradley and N. Sakimura, \u201cJSON Web Token (JWT),\u201d RFC 7519, IETF, May 2015.",
"[8] N. Provos and D. Mazi\u00e8res, \u201cA future-adaptable password scheme,\u201d in Proc. USENIX Annual Technical Conference, Monterey, CA, 1999, pp. 81\u201391.",
"[9] I. Fette and A. Melnikov, \u201cThe WebSocket Protocol,\u201d RFC 6455, IETF, Dec. 2011.",
"[10] W3C, \u201cWebRTC 1.0: Real-Time Communication Between Browsers,\u201d W3C Recommendation, 2021; and J. Rosenberg et al., \u201cSession Traversal Utilities for NAT (STUN),\u201d RFC 5389, IETF, 2008.",
"[11] OpenJS Foundation, \u201cExpress web framework documentation,\u201d 2026. [Online]. Available: https://expressjs.com",
"[12] W. E. Burr, D. F. Dodson, E. M. Newton, R. A. Perlner and W. T. Polk, \u201cSP 800-63B: Digital Identity Guidelines \u2013 Authentication and Lifecycle Management,\u201d NIST, Gaithersburg, MD, 2017.",
"[13] Office of the Australian Information Commissioner, \u201cAustralian Privacy Principles \u2013 Privacy Act 1988,\u201d Australian Government, 2024. [Online]. Available: https://www.oaic.gov.au/privacy/australian-privacy-principles",
"[14] OWASP Foundation, \u201cOWASP Top 10:2021 \u2013 The Ten Most Critical Web Application Security Risks,\u201d 2021. [Online]. Available: https://owasp.org/Top10/",
"[15] Australian Signals Directorate, \u201cInformation Security Manual,\u201d Australian Government, 2024. [Online]. Available: https://www.cyber.gov.au/resources-business-and-government/essential-cyber-security/ism",
"[16] Zhipu AI, \u201cGLM-4-Flash API documentation,\u201d 2026. [Online]. Available: https://open.bigmodel.cn",
]

# ----------------------------------------------------------------------------
# INDIVIDUAL SECTIONS (~1,000 words each)
# ----------------------------------------------------------------------------

IND_WANGZUZAN = {
"name": "WANGZUZAN", "topic": "Authentication, registration and login",
"paras": [
("_Contribution and responsibility._ I owned the entire authentication "
 "domain of Global Village end-to-end: the auth-server microservice "
 "(Node.js/Express, ES modules), the authentication PostgreSQL schema and "
 "its Docker stack (database on port 5434 with an Adminer console on 8082, "
 "service on port 3002), and the registration and login user experience. "
 "To the best of my estimation I completed 100% of the authentication "
 "backend and database implementation, 100% of the incremental database "
 "migration for security questions, and approximately 90% of the "
 "authentication UI (login, registration, email verification, forgot-"
 "password, change-password and security-question pages), with the "
 "remaining share consisting of widgets reused from the shared design "
 "system built jointly with the profile owner."),
("Against Section 4.2, my deliverables start with registration: email, "
 "username and password collection with server-side validation, SMTP "
 "verification codes that are time-boxed and single-use, a resend "
 "facility, case-insensitive uniqueness enforced by lower(email)/"
 "lower(username) indexes, and a terms-of-service step. Login issues "
 "JSON Web Tokens that embed a session version; when a password changes "
 "or is reset the version bumps, so every previously issued token is "
 "rejected by protected endpoints immediately. I implemented GET /auth/me "
 "and PATCH /auth/me for the profile owner, GET /auth/users/search for the "
 "chat owner's add-friend flow, and GET /auth/match/candidates for the "
 "profile matching tabs, which made authentication a shared foundation "
 "used by every other module."),
("I also delivered Google Sign-In by verifying Google ID tokens server-side "
 "with google-auth-library and linking accounts through a google_sub "
 "column, so Google-only accounts work without local passwords. Password "
 "recovery has two paths that I designed and implemented: the emailed "
 "six-digit code (SMTP) and a security-question path in which verification "
 "produces a single-use reset credential valid for five minutes; five "
 "failed answers lock the flow for fifteen minutes. The security-question "
 "tables were added by an idempotent migration (security-question-schema."
 "sql) that the service auto-applies at startup without touching existing "
 "accounts, which mattered because the October team merge had to preserve "
 "everyone's data. Hardening included bcryptjs hashing, an auth_rate_limits "
 "table for sensitive endpoints, and rejecting password-reset attempts that "
 "reuse old credentials."),
("On the frontend I built the login, registration and email-verification "
 "pages, the terms page, the forgot-password flow with its email-code and "
 "security-question variants, the change-password page used after login, "
 "and the security-question management UI inside the profile area. The "
 "registration form enforces paired question-and-answer input (both filled "
 "or both empty), the recovery flow clears sensitive inputs when switching "
 "methods, and the change-password page validates old-password correctness, "
 "new-old difference, confirmation match and length limits before "
 "submitting. The Google sign-in button integrates on web with a build-time "
 "client ID and degrades gracefully when the ID is absent, keeping email-"
 "password login fully functional."),
("The supporting infrastructure is also mine. The authentication PostgreSQL "
 "schema (users with uuid primary keys, bcrypt password hashes, security-"
 "question and answer-hash columns, google_sub and auth_provider fields, "
 "session_version) is defined in init.sql and mirrored by an auth_schema."
 "sql used for the standalone database image, with unique indexes on "
 "lower(email) and lower(username). The Docker stack composes the "
 "database, the auth service and an Adminer console so teammates could "
 "inspect data during development. For testing I configured the suite to "
 "run against a disposable database and a local SMTP server, never against "
 "the team's real data, and I maintained a separate live-PostgreSQL "
 "integration test for the registration-to-login path. When the one-click "
 "demo scripts were assembled, I supplied the auth seed accounts and the "
 "environment template that keeps real SMTP credentials out of the "
 "repository."),
("_Self-directed learning._ JWTs (RFC 7519 [7]) were new to me, and the "
 "session-version invalidation pattern required studying how to make "
 "logout-on-password-change actually revocable, since plain JWTs are "
 "otherwise valid until expiry. I learned OAuth-style ID-token verification "
 "for Google Sign-In, nodemailer and QQ SMTP configuration for verification "
 "emails, and password-storage guidance from NIST SP 800-63B [12] and the "
 "bcrypt paper [8]. On the testing side, I learned to run the auth suite "
 "against a disposable pglite database and a local SMTP server instead of "
 "the team's real database, and to write idempotent SQL migrations that a "
 "service can apply safely at startup. Docker Compose networking for "
 "PostgreSQL plus Adminer was also self-taught. Reading the OWASP "
 "password-storage guidance [14] and NIST SP 800-63B [12] changed my early "
 "design: I added rate limiting and single-use credentials after learning "
 "that verification codes that can be brute-forced or replayed are a "
 "common real-world flaw."),
("_Project management and teamwork._ We met weekly as a team and with our "
 "supervisor across the two semesters; I attended essentially all meetings "
 "and presented the auth service and its API contract before each "
 "integration checkpoint so the chat, community, family and profile owners "
 "could build against it. The two most demanding coordination moments were "
 "the October team merge, where I merged a teammate's security-question "
 "and password-recovery work into the current codebase using an "
 "incremental migration instead of a destructive rebuild, and the handoff "
 "of the search and match-candidate endpoints, where I adjusted response "
 "shapes after peer review comments from the chat and profile owners. I "
 "delivered my parts before each checkpoint, kept the 35-test auth suite "
 "green (45 tests at the October checkpoint after the merge), and fixed "
 "the integration test on a real PostgreSQL instance before delivery. I "
 "believe I contributed actively with ideas, for example proposing the "
 "lockout and single-use credential design that the group adopted."),
("Reflecting on quality of delivery: my parts were complete with passing "
 "tests before each of the four checkpoints, which left time for the "
 "corrections that peer review requested, most notably response-shape "
 "adjustments for the search and match endpoints and the migration review "
 "that preserved existing accounts during the security-question merge. My "
 "attendance at team and supervisor meetings was consistent, and I "
 "typically arrived with a working demo or a concrete API proposal rather "
 "than only questions."),
]}

IND_XUYONGQI = {
"name": "XUYONGQI", "topic": "Chat main page and sub-pages",
"paras": [
("_Contribution and responsibility._ I owned the chat experience of Global "
 "Village end-to-end: the chat main page and every sub-page, the chat "
 "microservice, its database, and the real-time calling infrastructure. "
 "To the best of my estimation I completed 100% of the chat UI (the home "
 "shell with the conversation list, request badge and navigation; add-"
 "friend, friend-requests and friend-profile pages; the one-to-one chat "
 "detail page; group chat with its management panel; the AI assistant "
 "page; and the one-to-one and group call pages), about 100% of the "
 "chat_service.dart REST client (~730 lines) and the chat-server "
 "(Express plus WebSocket), and roughly 85% of the session-state and "
 "storage helpers, where the profile owner later integrated a logout reset "
 "into my ChatSessionsState."),
("Against Section 4.3, my deliverables cover the full social loop. Users "
 "search people by email, username or name through the auth service, send "
 "requests, and manage them from a bell-notified requests page. "
 "Conversations persist text and recorded voice messages in the chat "
 "PostgreSQL (port 5435) with per-user read state. Group chats implement "
 "an owner/administrator hierarchy: owners promote, demote, mute, unmute "
 "and remove members and cannot be managed themselves; administrators act "
 "on ordinary members only; muted members see an explicit inline "
 "restriction. I built calls on flutter_webrtc: one-to-one calls present "
 "a full-screen incoming view with accept/decline, pulse animation and a "
 "timer, while group calls run a full-mesh topology over Google's public "
 "STUN servers, with an \u201congoing call \u2014 tap to join\u201d banner so late members "
 "can enter, and mute/camera/leave controls for everyone. Signalling rides "
 "the chat server's WebSocket at /ws?token=..., authenticated with the "
 "login token, with heartbeat pings and exponential reconnect backoff "
 "between one and thirty seconds. The AI assistant page proxies "
 "conversations to the hosted GLM-4-flash model [16] and keeps history "
 "server-side, with the API key held only by the backend. For "
 "demonstrations I seeded four call-test accounts and a demo group so "
 "group calls and mute/removal can be shown live in three browser "
 "windows."),
("The chat backend itself is my implementation: an Express service with a "
 "WebSocket server at /ws that authenticates by the login token, sends "
 "heartbeat pings and caps payloads at 256 KB. The REST surface covers the "
 "friend-request lifecycle (send, accept, decline, removal), conversation "
 "and message history with per-user read state, and the group endpoints: "
 "create, fetch, role changes, mute, unmute, remove member, add members, "
 "message history, read, leave and disband. Messages and friend "
 "relationships live in the chat PostgreSQL database (port 5435) "
 "provisioned by my Docker stack, with the AI proxy reading its model key "
 "from server environment variables so the key never ships in the client "
 "build."),
("Building the group-call experience required the most iteration. Any "
 "member can start a call; other online members receive a full-screen "
 "invitation; a late joiner sees the banner and joins the ongoing session. "
 "Each participant holds one peer connection to every other participant, so "
 "the page aggregates remote audio and video into a responsive grid with "
 "per-tile mute and camera indicators, a running timer and pulse feedback "
 "on incoming calls. I implemented microphone and camera toggles as track-"
 "level enables so they propagate without renegotiation, and leaving tears "
 "down only that participant's connections, keeping the rest of the call "
 "alive."),
("_Self-directed learning._ WebRTC was the largest learning effort: SDP "
 "offer/answer exchange, ICE candidate trickling, track handling and "
 " renegotiation, plus the practical difference between a full mesh and an "
 "SFU and why mesh degrades beyond a handful of participants, which I "
 "reported honestly in the limitations of Section 4.8. I learned "
 "web_socket_channel reconnect patterns, voice recording and playback on "
 "the web (the record package, audioplayers and blob URLs, with "
 "platform-specific readers for web, IO and a stub), role-based "
 "authorisation on the server, and Express plus ws service structure with "
 "JWT-gated routes and a 256 KB message cap. The GLM integration taught "
 "me server-side API-key handling and request design. Debugging cross-"
 "browser calls (Chrome to Chrome and Chrome to Android) taught me to log "
 "signalling state transitions, which is how I found and fixed a race "
 "where a declining peer left a half-open connection."),
("_Project management and teamwork._ I attended the weekly team meetings "
 "and most supervisor sessions, and I presented the chat flow and a live "
 "two-window call demo at two checkpoints, which produced the feedback "
 "that shaped the group-call banner and the mute-visibility rule. I "
 "coordinated the search contract with the auth owner early so friend-"
 "adding worked at the September baseline, reused the login JWT for "
 "signalling rather than inventing a second auth path, and accepted the "
 "profile owner's change to reset ChatSessionsState on logout, testing it "
 "against my page states. I delivered the friend-and-message core for the "
 "September baseline, group management for the October merge, and calls "
 "before the final demo, each with my session-state and storage suites "
 "passing inside the team's 105-test run. I estimate I contributed ideas "
 "actively, for example proposing the request-badge counter and the demo "
 "seed accounts that the whole team used for integration testing."),
("On delivery quality, my parts never landed at a checkpoint unfinished: "
 "the September baseline shipped working friends and messages, the October "
 "merge shipped group management with its authorisation rules, and the "
 "final demo shipped calls with the reconnection behaviour verified by "
 "killing the backend mid-call during testing. Where my estimates of "
 "shared work matter: I contributed roughly 15% of the shared home-shell "
 "navigation, because the conversation list, badge counter and AI preview "
 "anchor the application's main tab, and about 10% of the logout-cleanup "
 "design that the profile owner finalised."),
]}

IND_YINGHAOZHE = {
"name": "YINGHAOZHE", "topic": "Community module",
"paras": [
("_Contribution and responsibility._ I owned the community module end-to-"
 "end: the community user interface, the community microservice and its "
 "database. To the best of my estimation I completed 100% of the "
 "community backend (Node.js/Express on port 3000 with PostgreSQL on "
 "5433: activities, attendance and nearby-people endpoints) and 100% of "
 "the community UI, centred on community_page.dart, which at roughly "
 "3,500 lines is the application's largest page. The shared bottom-"
 "navigation shell and theme tokens were built jointly, but every "
 "community screen, form and state machine is my work."),
("Against Section 4.4, my deliverables are the location-centred community "
 "features. The feed lists activities within 500 metres with full create, "
 "edit, delete and attendance flows, including per-activity attendee "
 "management and check-ins that record presence. Nearby-people discovery "
 "renders an OpenStreetMap view through flutter_map with the device "
 "position from geolocator, a range circle overlay, and 10/20/50/100 "
 "metre selectors that stay synchronised with map zoom, so tapping a range "
 "or pinching the map updates the same query state. On the server I "
 "implemented the radius search with haversine-style latitude/longitude "
 "SQL on the activities and people tables, deliberately capping queries "
 "at a 100-metre maximum, 100 candidates and 10 returned users; switching "
 "the on-screen range filters the already-returned set client-side, so "
 "exploration costs no additional database load, a performance decision I "
 "presented to the team. Location sharing is strictly opt-in through "
 "device permission prompts, and the module never stores location history "
 "beyond the current position used for queries and check-ins. I also "
 "defined the module's blue-and-white visual language, which the team "
 "adopted for the map, feed, activity list and activity form."),
("The community backend is my implementation: a Node.js/Express service "
 "with activity endpoints (list, create, update, delete, attendee add and "
 "removal, current-attendee check) and the nearby-people search that "
 "accepts latitude, longitude and a radius, validates and caps the query, "
 "and returns at most ten candidates with the friend-status fields the UI "
 "expects. The activities and people tables live in the community "
 "PostgreSQL database (port 5433) provisioned by my Docker stack, and the "
 "service reuses the login token pattern of the other modules so no second "
 "authentication path exists."),
("On the frontend, community_page.dart is effectively four cooperating "
 "views over one state: the feed of activities within 500 metres, the map "
 "with its range circle and markers, the activity list with attendance "
 "counts, and the create/edit form with validation. I synchronised them "
 "through ValueNotifiers so a check-in or a join updates every view "
 "without manual refreshes, and I kept the map responsive by rebuilding "
 "only marker layers rather than the whole map widget. The range "
 "selector's four presets animate the circle and refilter the people list "
 "in a single pass, which is what makes the feature feel instant even "
 "though the underlying query is capped."),
("_Self-directed learning._ I taught myself flutter_map integration "
 "(tile layers, circle overlays, marker behaviour and gesture handling), "
 "the latlong2 coordinate API, and geolocator's permission flows on web "
 "and Android, including graceful degradation when a user denies "
 "location, which is easy to get wrong and was initially breaking my page. "
 "On the backend I learned geo-radius SQL queries without PostGIS, result "
 "capping for privacy and performance, and ValueNotifier-driven data "
 "sharing so the feed, map and list react to one source of state. Writing "
 "widget tests for map-dependent pages taught me stubbing location "
 "services and verifying state changes without real GPS. I also studied "
 "how to keep a very large page maintainable: extracting form widgets, "
 "keeping state setters single-purpose, and structuring the page so its "
 "four views can be tested independently."),
("For demonstrations I prepared seeded activities and check-in state "
 "alongside the demo accounts, so the map shows a populated neighbourhood "
 "out of the box. My two automated suites, nearby_map_location_test and "
 "nearby_people_service_test, cover permission-denied behaviour, radius "
 "filtering and query caps, and both run inside the team's 105-test "
 "suite. The seeded state also made our integration runs repeatable: the "
 "same neighbourhood appears on every fresh start, so a failing check-in "
 "flow is a code problem, never a data problem."),
("_Project management and teamwork._ I attended the weekly meetings and "
 "supervisor sessions consistently and showed the map and nearby-people "
 "flow at the September baseline and again after the October range-"
 "selector work, where feedback led me to add the synchronised zoom-to-"
 "range behaviour. I coordinated with the auth owner to reuse the login "
 "token and user search for displaying names in the feed, with the chat "
 "owner so activity attendees link to friend profiles, and with the "
 "deployment owner for the seeded demo accounts used by the one-click "
 "scripts. I delivered the activity feed and attendance first, then the "
 "map discovery, then the range selector refinement, keeping my two test "
 "suites (nearby-map and nearby-people service) green inside the team's "
 "105-test run and finishing each stage before the merge checkpoints "
 "rather than at the deadline. In discussions I contributed concretely, "
 "for example the client-side range filtering that the group adopted as "
 "the standard approach."),
("Beyond code, I documented my module's endpoints and the radius-capping "
 "rationale in the shared handoff notes so the others could integrate "
 "without reading my source, and my peer review of the profile owner's "
 "logout reset caught a case where the community map briefly kept a "
 "previous account's position, which we fixed before the final delivery. "
 "My parts were complete with their suites passing before each checkpoint, "
 "and my recorded contribution outside my own module is about 10% of the "
 "shared shell conventions that my screens were early adopters of."),
]}

IND_DAIZIHONG = {
"name": "DAIZIHONG", "topic": "Family module",
"paras": [
("_Contribution and responsibility._ I owned the family module end-to-end: "
 "the family UI, the family microservice and its storage. To the best of "
 "my estimation I completed 100% of the family backend (a zero-dependency "
 "Node service using node:http and node:sqlite on port 3003), 100% of the "
 "family-tree data model and consent engine (tree-store.js), and 100% of "
 "the family frontend (family_page.dart, the tree page and the tree "
 "canvas). This module was expanded twice during the project, and both "
 "expansions, from design documents to tests, are my work."),
("Against Section 4.5, the first expansion added multi-group family life: "
 "membership in several groups with a join preview requiring a real name "
 "and family role, a primary group, summary cards, activities, tasks, "
 "notes, manual daily check-ins, member management with role changes, "
 "invite codes, leave, and a combined notification feed. The second and "
 "larger expansion added the consent-based family tree. A requesting group "
 "shares a connection code; the target previews the request with a "
 "relationship label; explicit consent is required; and the link exists "
 "only after every affected group's administrator approves, with "
 "rejection, cancellation and a seven-day expiry. Role, code or topology "
 "changes invalidate affected pending requests so stale approvals can "
 "never be replayed. Administrators can disconnect their group's links and "
 "owners can leave the tree; connected components are capped at 50 groups; "
 "and links never expose another family's private records. The tree "
 "renders on a full-screen canvas I built with drag panning, pinch zoom, a "
 "\u201cshow all\u201d fit-to-screen action and group detail sheets. Approvals and "
 "disconnections execute inside SQLite transactions so partial failures "
 "cannot leave a half-connected graph. I also added a demo mode with "
 "isolated data for the portable distribution, and the Docker Compose "
 "family stack including its demo variant."),
("The family UI is organised as a dashboard over the user's groups: "
 "summary cards per group, a primary-group switcher, and per-group sections "
 "for activities, tasks, notes and a daily check-in that is deliberately "
 "manual rather than location- or time-inferred, because I wanted attendance "
 "to be an explicit act. Member management supports role changes, invites "
 "through codes, and leave, with the join flow showing a preview of the "
 "target group before any data is committed, so a wrong code or an unwanted "
 "group never creates membership silently. A combined notification feed "
 "summarises activities, tasks and tree events so nothing happens in a "
 "group the user cannot see."),
("The tree canvas is a custom interactive surface rather than a packaged "
 "graph widget: nodes are positioned by a layout pass over the connected "
 "component, and the canvas supports drag panning, pinch zoom, a fit-to-"
 "screen \u201cshow all\u201d action and per-node detail sheets. I kept the gesture "
 "recognisers independent of state updates so a pinch during a layout "
 "change cannot corrupt positions, and I bounded the rendered component at "
 "50 groups with an explicit message when the cap is reached, matching the "
 "server-side graph rule."),
("Beyond code, I wrote the module's feature specifications and handoff "
 "documentation (the family-tree feature plan and its review notes), which "
 "the team used at the October checkpoints, keeping integration discussions "
 "grounded in agreed behaviour instead of interpretation."),
("_Self-directed learning._ I taught myself node:sqlite's synchronous API, "
 "transactions and schema design, then deliberately built the service with "
 "zero npm dependencies on node:http to prove a portable design, which "
 "required hand-rolled routing, body parsing and per-user rate limiting. "
 "The tree taught me applied graph theory: preventing cycles, bounding "
 "connected components at 50 nodes, invalidating pending requests on "
 "topology change, and reasoning about which administrator must consent "
 "for a link to be legitimate, a consent-driven authorisation model I had "
 "not met in coursework. The canvas required learning transform "
 "mathematics for pan and pinch-zoom gestures and reconciling them with "
 "scroll and tap behaviours. Transaction design was another lesson: I "
 "first wrote approval as two separate updates and realised a failure "
 "between them could leave one side linked; wrapping approval and "
 "disconnection in SQLite transactions fixed it and became a dedicated "
 "test case. I also learned node:test for backend suites and widget "
 "testing for interactive canvases."),
("_Project management and teamwork._ I attended the weekly meetings and "
 "supervisor sessions throughout and drove this module through four "
 "documented stages: the September baseline groups, the October 16 family "
 "update, the documented feature plan for the tree (used by the team as a "
 "handoff specification), and the portable demo mode. Each stage shipped "
 "before its checkpoint with its tests passing: 34 Flutter tests across "
 "family page, group, identity, service, tree and canvas, and 35 backend "
 "tests across family, tree, identity and demo cleanup. I coordinated "
 "with the auth owner for token verification delegated to /auth/me rather "
 "than duplicating auth, and with the profile owner so logout resets did "
 "not corrupt my canvas state. My peer reviews of others' merges caught "
 "schema assumptions that would have broken family data, and I reviewed "
 "the merge manifests at the October checkpoints. I contributed actively "
 "in planning, for instance proposing the unanimous-approval rule and the "
 "seven-day expiry that the group adopted after debate, and I believe my "
 "delivery cadence, finished features with tests ahead of each checkpoint, "
 "gave the team stable ground for integration."),
("Against my own estimates, this module represents roughly a fifth of the "
 "application's frontend code and the largest single backend test "
 "contribution in the project, since the consent rules needed both "
 "permission tests and graph-rule tests. Where I helped others, I "
 "reviewed the merge manifests at both October checkpoints, verified that "
 "the auth delegation contract held when the service restarted, and "
 "confirmed that the portable demo mode seeded family data correctly on "
 "machines other than my own."),
]}

IND_HUANGZHIYONG = {
"name": "HUANGZHIYONG", "topic": "Profile module",
"paras": [
("_Contribution and responsibility._ I owned the profile module end-to-end. "
 "To the best of my estimation I completed 100% of the profile UI and "
 "state (profile_page.dart with the extracted profile_match_widgets.dart, "
 "profile_model.dart mapping and reset logic, and the profile tab's "
 "integration with the login and change-password flows) and 100% of the "
 "profile-related test suites. The profile sits at the intersection of "
 "every module, so I also invested heavily in cross-module state "
 "correctness, which I describe below."),
("Against Section 4.6, my core deliverable is the account-safe, server-"
 "first edit workflow. Fields that the server returns as empty now truly "
 "clear locally instead of being silently back-filled with stale values; "
 "the fabricated demo identity was removed so a half-loaded account never "
 "displays a placeholder name or email; and load, error and retry states "
 "block saving until a real profile has loaded, which prevents writing "
 "placeholder text back to the database. Email is read-only with an "
 "explanatory hint because it anchors the login identity. Saving runs "
 "local validation first (required name, username of 3\u201330 allowed "
 "characters, phone format, optional birth date), blocks duplicate "
 "submits with a busy state, and applies the update only after the "
 "server accepts, surfacing real errors and preserving the user's input "
 "on failure. Six TextEditingControllers are created once in initState "
 "instead of per build, fixing a leak. Keep-alive tabs with a lazy "
 "IndexedStack preserve unsaved edits across tab switches and across "
 "visits to the change-password and security-question pages. Logout asks "
 "for confirmation and resets currentProfile together with the chat "
 "owner's ChatSessionsState, so a shared device cannot leak one account's "
 "profile or chat summaries to the next. For matching, my Interest Match "
 "and Recommended tabs load candidates lazily on first entry rather than "
 "eagerly, filter zero-percent matches, cache results keyed by profile "
 "and candidate identities, render Google photo URLs for avatars with a "
 "letter fallback, and use a two-row interest input that survives narrow "
 "screens. This November hardening round followed the October merge, and "
 "I verified it end-to-end: flutter analyze clean, 105 of 105 tests "
 "passing (including eight previously failing UI tests), and a successful "
 "release web build."),
("The profile model layer is where correctness starts. "
 "profileFromAuthUser now distinguishes a field the server cleared from a "
 "field the server omitted: explicit empty strings, empty arrays and "
 "nulls produce empty local values instead of falling back to older "
 "cached text, which is what makes clearing a phone number actually save "
 "an empty phone number. I handled legacy accounts whose old schema "
 "stored a single interest string, mapping it into the current list-based "
 "model so old accounts see their data rather than an empty profile. The "
 "request-body builder omits a missing birth date rather than sending a "
 "placeholder, and the reset path rebuilds an emptyProfile() that every "
 "consumer can rely on."),
("The test suite is deliberately behavioural rather than cosmetic. "
 "profile_model_test asserts empty-field clearing, missing-field "
 "fallback, Google avatar mapping, legacy-interest conversion, the no-"
 "birth-date request body and logout reset; profile_page_state_test "
 "asserts that saving is blocked while the profile failed to load, that "
 "switching tabs and returning preserves unsaved edits, and that logout "
 "requires confirmation and clears both profile and chat-session state. "
 "These tests caught real regressions during my refactor, including one "
 "where a keep-alive change briefly reintroduced the controller leak I "
 "had fixed."),
("Because the profile page inherited code from the October merge, I "
 "documented every change in a dated changelog with verification records "
 "(tool versions, analyser output, test counts, build result) so the team "
 "could see exactly what the hardening round touched and what it did not, "
 "which kept the rest of the codebase frozen while I worked. I also "
 "documented the known gaps honestly: email editing awaits a backend "
 "verification endpoint, match candidates are capped at 200 per request "
 "with no pagination, and avatars support Google URLs only, all listed as "
 "future work rather than silently ignored."),
("_Self-directed learning._ The deep lessons were in Flutter state "
 "lifecycle: why recreating controllers on every build leaks state, how "
 "IndexedStack differs from route-based navigation for preserving edits, "
 "and how AutomaticKeepAliveClientMixin interacts with lazy loading. I "
 "learned the server-authoritative save pattern, accept-then-refresh "
 "instead of optimistic writes, and identity-keyed change detection for "
 "caching. Writing profile_model_test and profile_page_state_test taught "
 "me widget-level regression testing: asserting that offline saving is "
 "blocked, that tab switches preserve edits, and that logout requires "
 "confirmation and resets state. Mapping legacy fields (single interest "
 "strings on old accounts) taught me backward-compatible data handling. "
 "Beyond Flutter, I learned to treat a refactor as an experiment: "
 "extracting roughly 400 lines into a part file only landed after the "
 "tests were in place to prove the extraction was behaviour-preserving."),
("_Project management and teamwork._ I attended the weekly meetings and "
 "supervisor sessions and presented the profile workflow twice: after the "
 "October merge, when peer feedback identified the stale-placeholder save "
 "risk, and after the November hardening, where the supervisor's request "
 "for verification discipline led to the recorded analyse/test/build "
 "evidence. I coordinated continuously with the auth owner: consuming "
 "PATCH /auth/me, shaping GET /auth/match/candidates with filtering and "
 "cap awareness, and routing the change-password flow through the auth "
 "service so password policy and session invalidation stay consistent. "
 "With the chat owner I negotiated the logout reset of ChatSessionsState "
 "and tested it against conversation lists. I delivered the original "
 "profile with the September baseline and the hardening round before the "
 "final checkpoint, both times with my suites green inside the team's "
 "105-test run, and I estimate my contribution to the shared shell, "
 "theme and logout correctness at roughly 30% beyond my own module, since "
 "the profile touches every tab. In meetings I contributed actively, "
 "including proposing the confirmation-on-logout rule that the group "
 "adopted to protect shared devices during demonstrations."),
]}

INDIVIDUALS = [IND_WANGZUZAN, IND_XUYONGQI, IND_YINGHAOZHE, IND_DAIZIHONG,
               IND_HUANGZHIYONG]

# ----------------------------------------------------------------------------
# DOCX BUILDING
# ----------------------------------------------------------------------------

def set_base_styles(doc):
    st = doc.styles["Normal"]
    st.font.name = "Calibri"
    st.font.size = Pt(11)
    st.font.color.rgb = DARK
    pf = st.paragraph_format
    pf.line_spacing = 1.15
    pf.space_after = Pt(8)
    rpr = st.element.get_or_add_rPr()
    rfonts = rpr.get_or_add_rFonts()
    rfonts.set(qn("w:eastAsia"), "Calibri")
    for name, size, color in (("Heading 1", 16, BLUE),
                              ("Heading 2", 13, BLUE),
                              ("Heading 3", 11.5, BLUE)):
        h = doc.styles[name]
        h.font.name = "Calibri"
        h.font.size = Pt(size)
        h.font.color.rgb = color
        h.font.bold = True

def add_para(doc, text, justify=True, italic_lead=None):
    p = doc.add_paragraph()
    if justify:
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    if italic_lead:
        r = p.add_run(italic_lead)
        r.italic = True
    p.add_run(text)
    return p

def add_heading(doc, text, level=1):
    h = doc.add_heading(text, level=level)
    for r in h.runs:
        r.font.color.rgb = BLUE
    return h

def shade_cell(cell, hexcolor):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:fill"), hexcolor)
    tcPr.append(shd)

def add_table(doc, headers, rows, caption=None):
    if caption:
        c = doc.add_paragraph()
        c.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = c.add_run(caption)
        r.bold = True
        r.font.size = Pt(10)
    t = doc.add_table(rows=1, cols=len(headers))
    t.style = "Table Grid"
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    hdr = t.rows[0].cells
    for i, htext in enumerate(headers):
        hdr[i].text = ""
        run = hdr[i].paragraphs[0].add_run(htext)
        run.bold = True
        run.font.size = Pt(10)
        run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        shade_cell(hdr[i], "1F4E79")
    for row in rows:
        cells = t.add_row().cells
        for i, val in enumerate(row):
            cells[i].text = ""
            run = cells[i].paragraphs[0].add_run(val)
            run.font.size = Pt(10)
    doc.add_paragraph()
    return t

def build():
    doc = Document()
    set_base_styles(doc)

    # ---- Title page ----
    for _ in range(6):
        doc.add_paragraph()
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("COMP3851A/B \u2013 Computing and Information Sciences "
                  "Work Integrated Learning"); r.font.size = Pt(12)
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("School of Computer and Information Sciences"); r.font.size = Pt(12)
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("University of Newcastle \u2013 2026"); r.font.size = Pt(12)
    doc.add_paragraph()
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("FINAL REPORT \u2013 GROUP PROJECT"); r.bold = True
    r.font.size = Pt(14); r.font.color.rgb = BLUE
    doc.add_paragraph()
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run(TITLE); r.bold = True; r.font.size = Pt(18)
    r.font.color.rgb = BLUE
    doc.add_paragraph(); doc.add_paragraph()
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("Students:"); r.bold = True
    for name, num, topic in MEMBERS:
        p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.add_run(f"{name}  ({num}) \u2013 {topic}")
    doc.add_paragraph()
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run("Supervisor: [Supervisor Name]")
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run("Industry / Research Group: [Industry or Research Group Name]")
    doc.add_page_break()

    # ---- 1. Background ----
    add_heading(doc, "1. Background", 1)
    for para in BACKGROUND:
        add_para(doc, para)
    add_table(doc, TABLE1_HEAD, TABLE1_ROWS,
              caption="Table 1. Team structure and module ownership.")

    # ---- 2. Aims ----
    add_heading(doc, "2. Aims", 1)
    for para in AIMS:
        add_para(doc, para)

    # ---- 3. Methods ----
    add_heading(doc, "3. Methods and Activities", 1)
    for para in METHODS:
        add_para(doc, para)

    # ---- 4. Results ----
    add_heading(doc, "4. Results", 1)
    add_heading(doc, "4.1 Overall outcome", 2)
    for para in RESULTS_41:
        add_para(doc, para)
    add_table(doc, TABLE2_HEAD, TABLE2_ROWS,
              caption="Table 2. Deployed services, ports and storage.")
    add_table(doc, TABLE3_HEAD, TABLE3_ROWS,
              caption="Table 3. Automated test coverage and outcomes by module.")
    add_heading(doc, "4.2 Authentication (owner: WANGZUZAN)", 2)
    for para in RESULTS_42:
        add_para(doc, para)
    add_heading(doc, "4.3 Chat (owner: XUYONGQI)", 2)
    for para in RESULTS_43:
        add_para(doc, para)
    add_heading(doc, "4.4 Community (owner: YINGHAOZHE)", 2)
    for para in RESULTS_44:
        add_para(doc, para)
    add_heading(doc, "4.5 Family (owner: DAIZIHONG)", 2)
    for para in RESULTS_45:
        add_para(doc, para)
    add_heading(doc, "4.6 Profile (owner: HUANGZHIYONG)", 2)
    for para in RESULTS_46:
        add_para(doc, para)
    add_heading(doc, "4.7 Deployment and distribution", 2)
    for para in RESULTS_47:
        add_para(doc, para)
    add_heading(doc, "4.8 Critical analysis and limitations", 2)
    for para in RESULTS_48:
        add_para(doc, para)

    # ---- 5. Ethics ----
    add_heading(doc, "5. Ethics Considerations", 1)
    for para in ETHICS:
        add_para(doc, para)

    # ---- 6. References ----
    add_heading(doc, "6. References", 1)
    for ref in REFERENCES:
        p = doc.add_paragraph(ref)
        p.paragraph_format.space_after = Pt(4)

    doc.add_page_break()

    # ---- 7. Individual sections ----
    add_heading(doc, "7. Individual Sections", 1)
    intro = ("Each subsection below is the individual account of one team "
             "member, covering individual contribution with estimated "
             "percentages, self-directed learning, and project management "
             "and teamwork. Percentages refer to each member's own best "
             "estimation of their share of the corresponding result. Each "
             "subsection is submitted separately by its author as required "
             "by the course.")
    add_para(doc, intro)
    for i, ind in enumerate(INDIVIDUALS, start=1):
        add_heading(doc, f"7.{i} {ind['name']} \u2013 {ind['topic']}", 2)
        for para in ind["paras"]:
            if para.startswith("_"):
                lead, rest = para.split("._", 1)
                lead = lead.strip("_ ") + " "
                add_para(doc, rest, italic_lead=lead)
            else:
                add_para(doc, para)

    out = r"final report\GlobalVillage_Final_Report_Group.docx"
    doc.save(out)
    print("Saved:", out)

    # ---- word counts ----
    def wc(chunks):
        return sum(len(re.findall(r"[A-Za-z0-9][A-Za-z0-9'\u2019\-]*",
                                  c)) for c in chunks)
    print("BACKGROUND:", wc(BACKGROUND))
    print("AIMS:", wc(AIMS))
    print("METHODS:", wc(METHODS))
    print("RESULTS:", wc(RESULTS_41 + RESULTS_42 + RESULTS_43 + RESULTS_44
                         + RESULTS_45 + RESULTS_46 + RESULTS_47
                         + RESULTS_48))
    print("ETHICS:", wc(ETHICS))
    for ind in INDIVIDUALS:
        print(ind["name"], ":", wc(ind["paras"]))

if __name__ == "__main__":
    build()
