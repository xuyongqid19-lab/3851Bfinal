# Family Update — 10 November 2026

Start here when taking over this version. Based on `GlobalVillage_Azure_Team_20261110.zip`; this update is implemented and tested locally. Azure has NOT been deployed or modified.

## What changed
- Added name search in the Family tree overview and large canvas. Results show names on the left and family tags followed by personal tags on the right. Selecting a result rechecks access, expands its family and centres/highlights the exact person's row. Names are visible within the connected tree by default; private records and personal introductions are not exposed across families.
- Added family tags before family descriptions and personal tags in membership profiles. Create/join/profile/settings flows support up to five tags, optional values and 30 labelled colours. Family tags are administrator-controlled; personal tags and introductions are self-controlled. Joining members cannot edit shared family tags.
- Added persistent in-app link/disconnect/closure notifications with an unread badge and per-user read state. Link notifications are created only after the final required administrator approval. Refresh loads new notifications; this is not OS push or email.
- Added an explicitly enabled local demo: John Prince Family, with John, Emily, Daniel, Olivia and William Prince. These are fictional display members, not Auth accounts. Administrators can disconnect the link or separately remove the demo family. Normal disconnection preserves real families and their records.
- Extracted Family models, directory repository, tag/search widgets, notification page and canvas layout. Added Family-only identity/demo stores and versioned additive SQLite tables. Auth, Community, Chat and Azure routing business files remain unchanged. Four indirect SDK/test dependencies were resolved in `pubspec.lock`; no new package dependency was added.

## Code map
- `lib/features/family/`: new models, data repository, widgets and notifications.
- `lib/pages/family_page.dart`, `family_tree_page.dart`, `family_tree_canvas_page.dart`: entry points and flows; `lib/models/family_group.dart`: unread count.
- `family-server/src/identity-store.js`, `demo-store.js`: directory, tags, notifications and fixtures; existing store/tree/app/index files integrate them.
- `family-server/test/identity.test.js`, `demo-cleanup.test.js`, `test/family_identity_test.dart`: added coverage. Existing preview contract assertion now includes tags and linked-family count.
- `FAMILY_UPDATE_PLAN.md`: requirements and completion evidence. `PACKAGE_MANIFEST.json`: SHA-256 inventory.

## Run and configure
Use the existing `DATABASES_START_AND_INTEGRATION_GUIDE.md` for the four services and `AZURE_TEAM_HANDOFF.md` for the inherited hosting setup. Supply your own local environment values; credentials, populated databases, dependencies and SDKs are not bundled. `InitializeProject.cmd` / `RunWeb.cmd` remain the team's development entry points and require the documented tools/services.

Family requires Node >=24.14.0, `FAMILY_DB_PATH`, `AUTH_API_ME_URL` and the appropriate `ALLOWED_ORIGINS`. Run `node src/index.js` from `family-server`. The included `build/web` is a release build using `PORTABLE_WEB=true`; serve it through the existing same-origin gateway providing `/api/auth`, `/api/community`, `/api/chat` and `/api/family`. Opening `index.html` directly is insufficient. To rebuild: `flutter pub get`, then `flutter build web --release --no-web-resources-cdn --dart-define=PORTABLE_WEB=true`.

Demo mode is OFF by default and blocked when `NODE_ENV=production`. For an isolated local demo, stop the normal local Family container first, then use `docker compose -f docker-compose.family-demo.yml up --build -d`. This uses its own database volume and expects local Auth on port 3002. Use the normal local Flutter run on port 7357. Family tree > Manage > Add demo family creates the fixture; Disconnect family and Remove demo family are separate actions. Never combine this demo compose file with the Azure compose file.

## Database and rollback
Back up the existing Family database before starting the new server. With the Family Node runtime, run `node tools/BackupFamily.mjs <existing.sqlite> <new-backup.sqlite>`; this produces a consistent snapshot including committed WAL changes and refuses to overwrite a destination. Startup automatically adds schema version 1 tables and backfills opaque directory IDs without resetting existing records. No Auth/Chat/Community database migration is needed.

To restore, stop Family, preserve the entire current database directory (including WAL/SHM files) separately, place the snapshot at `FAMILY_DB_PATH` in a clean directory, and restart the matching server version. Never mix old WAL/SHM files with a restored snapshot. Restoring a pre-update snapshot also discards changes made after that snapshot. Legacy-data migration, reopen/read-state persistence, compatible old-column reads and backup/restore are covered by tests.

## Validation and remaining limits
- Flutter: 105/105 tests passed (including the two new Profile test files). Family API: 45/45. Auth: 75/75.
- Whole-project analysis: clean (0 error / 0 warning / 0 info) on Flutter 3.44.6 after the Profile follow-up; the four style infos in unchanged teammate pages were fixed.
- Profile follow-up (10 November): demo profile removed, server-field clearing fixed, load/error states block saving stale placeholders, Email read-only, save only publishes after server success, edits survive tab/page navigation, logout confirms and clears profile/chat state, match candidates lazy-load with 0% filtering. Email change, candidate pagination and local avatar upload remain future work.
- Release Web build passed. Actual desktop/mobile browser flows passed: tags, all colour options, demo, search/centring, unlink/removal, two-admin real-family linking, notifications, real Auth login, Chat exchange and Community read. No browser page errors.
- Archive CRC and file hashes verified. No production data or test accounts included. Android build/device validation and production Azure validation were not performed for this update. Existing Google/SMTP integrations still require the team's own configuration.

Future work should keep Family permissions and data ownership isolated. Do not expose Auth identifiers or private records through the tree directory, bypass administrator approvals for real families, or seed demonstration data in production.
