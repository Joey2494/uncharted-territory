# Knight animations

- Author: Kay Lousberg — https://www.kaylousberg.com/
- Official source: https://kaylousberg.itch.io/kaykit-character-animations
- Pack: KayKit Character Animations FREE 1.1
- License: CC0 1.0 Universal; the original animation pack license is preserved in `License.txt`.
- Extracted on: 2026-11-02 with Godot 4.7.2.

`locomotion.tres` is a self-contained Godot AnimationLibrary extracted from these official GLB files:

| Clip | Source |
|---|---|
| `Idle_A` | `Animations/gltf/Rig_Medium/Rig_Medium_General.glb` |
| `Walking_A` | `Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb` |
| `Running_A` | `Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb` |

All three locomotion clips use linear looping and the original skeleton tracks. Their paths resolve relative to `Knight`, not to the physics root or the Model wrapper. No source mannequin or root-motion-driven player movement is included.

`scenes/player/player_locomotion.gd` owns idle/walk/run selection and 0.12-second crossfades. It uses `CharacterBody3D.get_real_velocity()` after movement and collision, so a blocked player returns to idle. Full-speed animation cadence is configured separately with `walk_playback_speed = 1.0` and `run_playback_speed = 1.25` on the `LocomotionAnimation` node. Slower actual movement reduces the selected cadence proportionately, with a 0.25 minimum ratio; it never speeds the animation beyond the configured cadence. This prioritizes natural arm swing over exact foot planting at the character's much faster physical travel speed. Idle_A retains its original 1.0x rate. The source animations and bone tracks are unchanged.

Controls: WASD / arrow keys walk at 5 m/s; hold Shift to run at 8 m/s (`Player.walk_speed` / `Player.move_speed`). Walking_A now plays at 1.0x rather than approximately 9.73x, and Running_A at 1.25x rather than 3.44x. Physical movement values are unchanged. The gait threshold follows the midpoint of the configured walk/run speeds. Release direction keys to idle. Dodge, Hit_A and Q casting temporarily take over locomotion as described below. Death stops locomotion and plays Death_A.

## Player melee presentation

`melee.tres` is a separate self-contained AnimationLibrary containing the one-shot `Melee_1H_Attack_Slice_Diagonal`, extracted from the same FREE 1.1 pack's `Animations/gltf/Rig_Medium/Rig_Medium_CombatMelee.glb`. It uses the same CC0 license and matching Rig_Medium skeleton. Its original bone tracks are preserved.

`scenes/player/player_attack_animation.gd` binds the existing player's `MeleeAttack.attack_started`, `attack_finished` and `hit_detected` signals. It derives elapsed attack time from the public cooldown clock and samples the source clip in three segments:

| Existing gameplay time | Original clip time | Pose |
|---|---|---|
| 0.00–0.08 s | 0.00–0.38 s | Prepare and bring the sword toward contact |
| 0.08–0.20 s | 0.38–0.50 s | Diagonal strike through the front hit sector |
| 0.20–0.36 s | 0.50–1.00 s | Follow-through and recovery |

These gameplay durations are read from the existing MeleeAttack instance; the table describes its current default values. The source breakpoints can be fine-tuned with `slash_start_ratio` / `slash_end_ratio` on the player's `AttackAnimation` node. No animation method track causes damage or changes collision queries, cooldown, attack range or damage values. The original shared `melee_attack.gd` and `MeleeAttack.tscn` are unchanged.

During the slash, the locomotion layer yields the AnimationPlayer to the attack presentation, which uses manual sampling against the same gameplay clock. The model's yaw compensates for Visuals turning so the sword keeps the attack's captured direction while movement remains available. Completion/cancellation restores the original model yaw and physics animation processing, and returns control to idle/walk/run. Dodge and death still cancel the existing attack.

A same-pack sword is attached to `handslot.r` through a runtime BoneAttachment3D under the player's Skeleton3D. Only this player's three old procedural weapon meshes are hidden; the original range preview stays active, and enemy/Boss weapon displays and shared combat logic are untouched. The sword is visual only and does not replace the sector-based hit query with blade collision.

## Knight directional dodge presentation

`dodge.tres` contains the four non-looping `Dodge_Forward`, `Dodge_Backward`, `Dodge_Left` and `Dodge_Right` clips extracted on 2026-11-03 from FREE 1.1 `Animations/gltf/Rig_Medium/Rig_Medium_MovementAdvanced.glb`. The original Rig_Medium bone tracks and CC0 license are preserved; no mannequin mesh or physics-root track is included.

`scenes/player/player_dodge_animation.gd` selects the nearest cardinal direction from `Player.get_dodge_direction()` relative to Visuals' starting facing (-Z forward, +X right). Exact diagonals prefer forward/back; no-input dodge uses the existing facing fallback. Visuals retains its starting yaw during dodge so lateral/backward clips stay aligned with actual travel. The old vertical scale compression is removed.

The controller manually samples each complete 0.4-second source clip using `Player.get_dodge_progress()`, synchronizing it to the existing default 0.2-second physical dodge (equivalent to 2x playback). The duration is captured when the dodge begins, so custom durations and changes to the exported setting mid-dodge do not desynchronize the pose. Physical displacement remains controlled by `move_and_slide()`; animation does not drive collision, damage, invulnerability, cooldown, or attack cancellation. At completion/cancellation, animation processing and idle/walk/run control are restored. Only Player.tscn binds this layer; other characters and shared melee logic are unchanged.

## Knight damage reaction

`hit.tres` contains the non-looping `Hit_A`, extracted on 2026-11-03 from FREE 1.1 `Animations/gltf/Rig_Medium/Rig_Medium_General.glb`. Its original 0.666667-second duration, Rig_Medium bone tracks and CC0 license are preserved.

`scenes/player/player_hit_animation.gd` listens to the existing `Player.damage_received` signal, which is emitted only after accepted HP loss. Enemy melee, Boss melee and Boss charge all reach the existing `take_damage()` path. Rejected/immune hits do not play or restart Hit_A. Fatal hits skip Hit_A because Player sets its death flag before emitting the signal. Dodge also has priority: damage during a dodge never replaces its pose, and starting a dodge explicitly cancels an active Hit_A before the dodge controller takes animation ownership. A suppressed reaction is not queued for later playback.

Hit_A plays once at its original rate using manual physics sampling; pausing the player also pauses the reaction. It then returns control to idle/walk/run based on actual movement. A new accepted nonfatal hit restarts Hit_A without recapturing the manual callback mode. This affects presentation only: no stun, knockback, attack cancellation, or additional invulnerability is introduced. HP, hit flash, damage values, collision, attack hit windows and cooldowns remain controlled by the existing scripts.

During Hit_A, AttackAnimation suspends only its skeleton sampling and restores Model's resting yaw. The ongoing attack can still hit, finish or start on its existing clock without taking animation control from Hit_A. If an attack is still active when the reaction ends, its presentation resumes at the current combat phase; otherwise locomotion resumes. Death cancels the reaction without restarting movement or attack animation. Only the Knight player's scene binds this layer; other actors and shared combat scripts are unchanged.

## Knight Q cast presentation

`magic.tres` contains the non-looping `Ranged_Magic_Shoot`, extracted on 2026-11-03 from FREE 1.1 `Animations/gltf/Rig_Medium/Rig_Medium_CombatRanged.glb`. The original 0.933333-second clip and Rig_Medium bone tracks are preserved under the same CC0 license; there are no method/event tracks.

`scenes/player/player_cast_animation.gd` listens only to `EnergyShock.released(projectile)`. The existing skill generates its projectile immediately inside `try_cast()`, so the controller synchronously samples the source's outstretched-hand pose at 0.30 seconds (frame 9 at 30 FPS), then plays the remaining approximately 0.633333 seconds at the original rate. Source hand-pose inspection and screenshots are in `output/player-cast-animation-2026-11-03`. `CastAnimation.release_time` can fine-tune that source offset. The windup is skipped to preserve the existing immediate firing time; no new casting delay or gameplay timer is added.

EnergyShock remains the only projectile producer. The animation layer never calls `try_cast()` or instantiates a projectile, so cooldown rejects and keyboard echoes cannot start extra animation-driven shots. Damage, attack buffs, range, swept collision, spawn location, speed, cooldown, cast effect and impact effect remain in their original scripts and scenes, unchanged.

The model faces the captured projectile direction during the pose while physical movement and turning remain available. Completion restores the model yaw and animation callback mode, and returns to locomotion or an ongoing melee attack at its existing phase. The presentation never cancels or delays melee hit queries. New accepted Q releases replace the displayed hit reaction; new accepted damage interrupts casting with Hit_A. Dodge/death cancel cast presentation, and an already launched projectile remains under its original lifecycle. Suppressed/interrupted cast poses are not queued or replayed. All bindings are confined to the Knight player.

## Knight death and settlement

`death.tres` contains the complete, non-looping 0.8-second `Death_A`, extracted on 2026-11-03 from FREE 1.1 `Animations/gltf/Rig_Medium/Rig_Medium_General.glb`. Original Rig_Medium bone tracks and the same CC0 license are preserved; there are no gameplay or physics-root tracks.

Player's existing `take_damage()` still owns HP loss, the immediate dead flag, hit flash, attack/dodge cancellation and the immediate `died` signal. Movement stops and movement/combat input is disabled immediately. Existing skill, item and damage guards continue rejecting dead players. The new `DeathAnimation` node is last in Player.tscn so existing died handlers release lower-priority animations before it plays Death_A from source time zero at 1x speed. It manually samples the full clip, retains the final pose and emits `Player.death_animation_finished` exactly once. It does not change HP, damage acceptance or death detection.

Main enters `DYING` as soon as it receives `died`: the run clock stops, the death room is captured and victory/start events cannot replace death. The dungeon continues processing during the death action, including existing projectile/effect lifecycles. Only after `death_animation_finished` does Main enter the original `DEAD` state, disable DungeonTest and show the existing death result screen. Repeated completion notifications cannot create another settlement screen. Existing MENU/PLAYING/DEAD/VICTORY enum values are preserved.

Restart still uses the original deferred, duplicate-protected `reload_current_scene()` path. A new scene recreates the Knight skeleton, idle pose, full HP, inputs, action state and cooldowns; it has no pending death callback from the previous scene. DeathAnimation emits no completion signal on removal. No other character's death animation or shared combat/UI scene is modified.
