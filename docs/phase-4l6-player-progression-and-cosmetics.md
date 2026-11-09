# Phase 4L.6 — Player Progression and Cosmetics

## Architecture

Progression is local and player-owned. `ProgressionService` reads persisted game
results through the existing result repository, calculates awards with
`ProgressionRules`, and stores idempotent awards and cosmetic unlocks through
`ProgressionRepository`. The stable `PlayerProfile.id` is the ownership key.
The existing profile repository remains the only source of the equipped avatar.

The initial audit found five existing profile avatar choices. They remain
available by default. The catalog adds five inexpensive emoji cosmetics within
the same avatar field and Avatar Studio flow. Achievements, challenges, result
ownership, and avatar persistence are reused; no account, economy, or second
avatar store was added.

## XP and levels

Only a successfully persisted, owned result in `GameSessionState.results` with
a positive database result ID and completion timestamp is eligible. Each result
earns:

```text
100 + min(score ~/ 100, 50) + min(catches * 5, 50)
```

This yields 100–200 XP per verified round. Input mode is irrelevant, so
Touch-Only and Smile rounds use the same formula. Camera access, face
observations, advertisements, screen visits, unverified results, and historical
NULL-owner results earn no XP.

Levels are derived rather than trusted from UI input: level 1 begins at 0 XP,
level 2 at 500 XP, level 3 at 1,000 XP, and each further level requires another
500 XP. The UI displays total XP and progress within the current level.

`player_progression_awards` has a `(player_id, result_id)` primary key. Repeated
save callbacks, retries, synchronization, and restarts therefore cannot award a
result twice. A failed optional post-save progression callback cannot invalidate
the saved game result; the next progress or Avatar Studio synchronization
recovers any missing award from persisted results.

## Cosmetic catalog

| Cosmetic | Requirement |
|---|---|
| Ninja, Curly Hero, Classic Hero, Classic Star, Bright Star | Available by default |
| Super Hero | Reach level 2 |
| Smile Wizard | Reach level 3 |
| Smart Glasses | Complete 5 verified rounds |
| Champion Crown | Unlock Dedicated Player |
| Festival Mask | Unlock First Catch |

All requirements can be reached without camera access. Achievement-based
requirements use existing verified result achievements. Locked choices display
their requirement and current level/round/achievement progress. Only unlocked
choices invoke profile avatar updates. Reset equips the default Ninja avatar but
does not delete unlock records.

Profile, Home, gameplay, Results, and other existing avatar consumers continue
to observe `playerProfileProvider`; an equipped cosmetic therefore propagates
through the same authoritative profile path as the original five choices.

## Persistence and migration

Schema version 7 adds:

- `player_progression_awards`: stable player ID, result ID foreign key, derived
  XP, and award timestamp; the composite primary key enforces idempotency.
- `player_cosmetic_unlocks`: stable player ID, cosmetic ID, unlock timestamp,
  and human-readable rule source; the composite primary key prevents duplicate
  unlocks.

The v6-to-v7 migration only creates these tables. Existing profiles, avatars,
results, achievements, challenge assignments, and engagement metadata remain
unchanged. Progression is reconstructed from eligible persisted history on
first synchronization. Player A and Player B use separate award and unlock rows,
and profile replacement cannot transfer an original result's ownership.

Result persistence and progression synchronization are separate because a game
result must remain durable even if optional milestone processing fails. The
award primary key and reconstruction provide retry safety and eventual recovery.
This is local SQLite persistence, with no cloud or cross-device synchronization.

## UI and accessibility

Profile links to Player Progress without crowding the identity card. The screen
shows player level, total XP, progress to the next level, lifetime verified
rounds, the full cosmetic catalog, recent unlocks, and links to Achievements and
Challenges. Progress has a semantic label. Avatar Studio marks locked choices,
announces availability and progress to assistive technology, and prevents
selection of locked items.

## Privacy, performance, and trust limits

Progression stores result IDs, derived XP, cosmetic identifiers, and timestamps.
It stores no camera frames, face images, embeddings, or new personal data. It
does not initialize camera or ML Kit and adds no advertising integration.
Synchronization is performed after result persistence or when a progression UI
is opened; there are no per-frame writes. Catalog and rule evaluation are small
in-memory operations.

The Phase 4L.5 local-clock limitation remains. Daily challenge dates and streaks
are useful local engagement signals but are not trusted for cosmetic reward
eligibility here. The app does not claim strict offline clock anti-tamper
protection.

## Automated coverage

Focused tests cover XP rules and boundaries, Touch-Only parity, level thresholds,
all requirement types, default and persisted unlocks, retry idempotency, restart
restoration, NULL/unverified exclusion, Player A/B isolation, profile replacement,
schema v7 and v6 migration, Avatar Studio locking/equipping/reset, and Player
Progress rendering from real in-memory SQLite data. Existing identity, Results,
achievements, challenges, analytics, gameplay, privacy, and lifecycle tests remain
part of the full suite.

Flutter execution and physical-device evidence must be reported separately from
static checks. No physical Android or iOS validation is claimed by this document.
