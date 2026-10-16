# Phase 3.5 — Avatar presentation

## Audit and scope

The profile screen previously rendered a hard-coded ninja emoji. There is no
avatar editor, selected-avatar record, image, custom-parts configuration, or
profile repository. Drift stores game results only. Consequently this phase is
**PARTIALLY COMPLETE**: the integration boundary and presentation are implemented,
but loading an actual user-saved avatar awaits the missing profile prerequisite.
No database schema or parallel persistence system was added.

Phase 3.4 connects the existing real mouth/face tracking provider to Flame's
normalized catching target. Gameplay has no camera preview; calibration retains
its preview. This change does not create a camera controller or change tracking.
Hardware behavior has not been verified in this environment.

## Data flow and rendering

`ProfileAvatarRepository.watchAvatar()` → Riverpod `profileAvatarProvider` →
profile screen and gameplay → cached Flame canvas portrait.
The production adapter explicitly emits no selection. Loading, missing, invalid,
or failed reads resolve to the existing ninja fallback. A future profile adapter
must read the established profile persistence and emit selection changes here.
The supported representation is the existing static emoji text, not PNG or
facial expression sprites. Repository overrides exercise saved-selection/live
change behavior in tests; they are not evidence of production avatar storage.

`MuskaanFlameGame._drawTarget` retains the target position and ring and delegates
its inner content to `AvatarPresentation`, following the existing canvas renderer.
The portrait is centered, uniformly scaled, circularly clipped, and framed by a
purple aura. Text layout is cached until the symbol changes. No network, image
decoding, particle system, or additional package is needed.

## Reactions and ownership

- Idle: 1.8% breathing scale.
- Catch: 8% bounce with green accent.
- Every third consecutive catch: 13% celebration with gold accent.
- Hazard or actual uncaught food leaving the screen: small contraction/pink accent.
- Game over: 600ms settling transition before existing game-over/results flow.
- Pause: reaction clock freezes; restart clears counters and presentation.

Round-local cumulative catches/hazards/misses identify new events. A session
listener handles every state emission, independent of tracking frequency and UI
rebuilds. Save-state changes cannot replay game over. The added miss counter is
presentation metadata only; scoring, combo, life, collision, and database rules
are unchanged. Existing silent food expiry remains unchanged.

The Flame update clock drives presentation without animation timers. The screen
owns and cancels the single results-navigation timer, closes subscriptions, and
disposes the cached TextPainter. Replacing a portrait disposes its previous
TextPainter. Disposal is idempotent and ignores subsequent presentation work.
There are no owned image resources. Reduced motion disables avatar scale motion
and the additional game-over delay; existing unrelated HUD animations remain.

## Verification (cloud environment)

- `flutter pub get`: passed with `PUB_CACHE=/workspace/.pub-cache`. The first
  attempt used a read-only home cache; rerunning with the existing workspace
  cache resolved that environment issue.
- `flutter analyze`: passed, no issues.
- `flutter test`: passed, 177 tests, including five new avatar tests and the
  extended gameplay flow regression (fallback and live avatar replacement).
- `flutter build apk --debug`: passed using the existing workspace Android SDK,
  JDK 17, Gradle proxy configuration, and aapt2 override.
- `git diff --check`: passed.
- `adb devices`: no device attached.

The navigation regression was updated to advance the test clock through the new
600ms avatar transition before the existing 1600ms game-over screen timer.
Physical visual quality, emoji rendering on Android, hidden-camera control,
complete-round performance, pause/background/replay, and real saved-profile
integration remain unverified. Verify these on hardware after implementing the
profile editor/persistence adapter. Unit/widget tests do not establish those
runtime outcomes.

## Files

Added `profile_avatar.dart`, `avatar_presentation.dart`, avatar tests, and this
report. Updated the profile screen, Flame renderer, gameplay screen, session
provider (miss counter), and gameplay-flow regression test.
