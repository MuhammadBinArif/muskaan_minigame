# Phase 4L.1 player identity completion report

> Ownership storage was subsequently migrated to schema version 3. See `phase-4l.1b-result-ownership-avatar.md` for the current result schema.

Date: 9 November 2026. All work remains local and uncommitted. No physical device was used.

## Audit findings

The Phase 4L profile is already the authoritative local identity: `PlayerProfileRepository` stores one immutable-ID profile in the existing Drift database, and `playerProfileProvider` publishes durable name/avatar edits. Gameplay snapshots that ID, name and avatar when a round starts; `session_details` stores ownership without changing the version-1 result table. Reads left version-1 history unassigned.

The remaining disconnects were:

- Welcome's Skip action navigated directly to Home without reading or completing the profile. A direct/restored Welcome route could therefore bypass initialization.
- The production session provider used `requireValue`; profile loading/error could throw instead of safely refusing an unowned round.
- Result persistence did not explicitly guard the production path against an absent identity.

The avatar is no longer separately persisted. `ProfileAvatar` is a presentation adapter over `PlayerProfile.avatar`; Avatar Studio writes through `PlayerProfileController`. Profile, Flame gameplay, Results and `PlayerIdentity` all resolve that same value. No older standalone avatar persistence implementation was found to migrate.

## Implemented behavior

1. **Welcome paths — PASS (source)**: opening Welcome starts the existing profile controller. Skip awaits that same initialization, marks the existing profile onboarded, and enters Home. It routes to setup if initialization has no valid profile. The normal walkthrough initializes without changing the ID. Restart-safe creation remains transactional in `loadOrCreate`.
2. **Authoritative profile — PASS (source)**: stable 128-bit ID, validated display name, avatar, creation/update timestamps and onboarding state remain in one persisted model. Name/avatar edits retain the ID.
3. **Avatar synchronization — PASS (source)**: Avatar Studio, Profile, Home, gameplay, Results and local leaderboard identity use the profile avatar reactively. The persisted avatar restoration test uses a real file connection restart.
4. **Gameplay and Results identity — PASS (source)**: production gameplay refuses to start while profile state is unavailable. A round snapshots stable ownership; current name/avatar may update presentation only when the stable ID matches. A profile error cannot silently create an unowned result.
5. **Result ownership and migration — PASS (source/SQL smoke), Drift runtime NOT TESTED**: schema version 2 adds `session_details` keyed by the existing result ID. New application rounds require ID/name/avatar before persistence. Save and retry retain the same immutable result ID and use one transaction. Version-1 rows remain unchanged, retain score/state fields, and read with null ownership. No current player is inferred.
6. **Leaderboard boundary — PASS (source)**: the leaderboard is explicitly labelled on-device and not server verified. Stable IDs group local scores. Current-player rows resolve the current authoritative name/avatar; unknown history is labelled ownership unknown. No backend was added.
7. **Privacy/performance — PASS (source audit)**: identity remains local. No face data, camera images, embeddings, advertising identity sharing, analytics or remote account infrastructure was added. Profile writes occur only on creation/edit/onboarding completion.

## Tests added or retained

- Welcome normal-path identity preservation.
- Welcome Skip initialization, onboarding completion and ID preservation.
- Missing production profile cannot start or save an unowned round.
- Existing first-launch setup, profile editing, reactive avatar/name, Touch-only owned result, current identity presentation and leaderboard journey.
- Version-1 migration with historical unassigned ownership.
- Real database restart restoring the same ID, name and avatar.
- Result retry/idempotency and gameplay regression coverage remain present.

## Verification

| Check | Status | Evidence |
| --- | --- | --- |
| Supplemental Dart formatter | PASS | 39 changed/new Dart files processed; repeated run required no manual formatting |
| Dart syntax parser | PASS | Zero syntax errors across `lib` and `test` |
| `git diff --check` | PASS | No whitespace errors |
| Security/manifest checks | PASS | Manifest, plist/ATS, signing and symbol policies passed |
| Python tooling tests | PASS | 3/3 passed |
| `flutter analyze` | BLOCKED | Flutter SDK bootstrap failed: network proxy returned CONNECT 403 for the Dart SDK artifact |
| `flutter test` | BLOCKED | Same unavailable Flutter/Dart SDK; no Flutter test result is claimed |
| Physical-device verification | NOT TESTED | No Android or iOS device was available |

## Files changed for Phase 4L.1

- `lib/features/onboarding/presentation/screens/welcome_screen.dart`
- `lib/core/providers/game_session_provider.dart`
- `test/profile/identity_flow_test.dart`
- `test/session_regression_test.dart`
- `docs/phase-4l.1-player-identity.md`

These extend the existing uncommitted Phase 4L files described in `docs/phase-4l-identity-smile.md`.

## Remaining limitations

- **BLOCKED:** Flutter type analysis and automated Flutter execution require a usable SDK artifact host or preinstalled SDK.
- **NOT TESTED:** rendering, lifecycle and database behavior on a physical device.
- **PASS with boundary:** identity and leaderboard are local to one database/device. There is no account recovery, global leaderboard or server verification.
- **PASS with migration boundary:** historical rows without trustworthy identity remain unassigned permanently unless a future product supplies verifiable ownership evidence.
