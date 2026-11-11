# KayKit Barbarian character model

2026-11-11 role update: this body is now the playable Iron guard, with separate round-shield and armor presentation. The first-level Boss now uses `../BronzeGatekeeper.tscn`. The original import and animation notes below are retained for provenance.

- Author: Kay Lousberg — https://www.kaylousberg.com/
- Source: https://kaylousberg.itch.io/kaykit-adventurers
- Pack: KayKit Adventurers FREE 2.0 (ordinary Barbarian, not the EXTRA Large variant).
- Original file: `Characters/gltf/Barbarian.glb`, copied without modification.
- License: CC0 1.0 Universal; the original pack license is preserved in `License.txt`.
- Integrated on: 2026-11-03.

`scenes/bosses/RuinGatekeeper.tscn` instances this model under the independent
`Visuals/Model` wrapper. Uniform scale 1.168 gives the source's approximately
2.397775 m mesh bounds a height of approximately 2.800601 m. The wrapper rotates
180 degrees around Y to align the asset's +Z front with the Boss Visuals' -Z
front. Feet remain at Y=0; no vertical offset or physics-root scaling is used.

The matching 23-bone Rig_Medium skeleton uses `Idle_A` from the existing shared
CC0 `../animations/locomotion.tres` library to display a natural standing pose.
Its AnimationPlayer targets only the character skeleton. The Boss-only
`scenes/bosses/boss_melee_animation.gd` adds the two-handed slice described below;
there is no root motion, weapon collider, or animation damage event.

The seven old placeholder body meshes and their unused materials/meshes were
removed. `Visuals/ChargeTrail`, the root charge warning, collision, attack scene,
hit flash, health UI, immediate death detection and exit unlocking are preserved.
Existing gameplay drives all movement and attacks; corpse removal now follows
the complete Death_A as described below.

Godot extracts `Barbarian_barbarian_texture.png` on GLB import. Keep the extracted
texture and generated import settings with the source model.

## Two-handed melee presentation

`animations/melee.tres` contains the complete, non-looping 1.1-second
`Melee_2H_Attack_Slice`, extracted from KayKit Character Animations FREE 1.1
`Animations/gltf/Rig_Medium/Rig_Medium_CombatMelee.glb`. Its original 28 skeleton
tracks are preserved. The animation pack's CC0 license is included alongside it;
official source: https://kaylousberg.itch.io/kaykit-character-animations.

The controller listens to the existing MeleeAttack signals and manually samples
the animation from its public cooldown clock. With current combat settings:

| Gameplay time | Source animation time | Presentation |
|---|---|---|
| 0.00–0.65 s | 0.00–0.35 s | Wind up with the original warning |
| 0.65–0.81 s | 0.35–0.60 s | Sweep the axe through the active hit window |
| 0.81–1.16 s | 0.60–1.10 s | Follow through and recover |

The source contact window was inspected frame by frame. `slash_start_time` and
`slash_end_time` tune only the sampled source pose; gameplay durations are read
from the existing attack, and no combat values are changed. The controller runs
after the combat physics step and updates the pose synchronously on hit contact
before the existing damage call. The visible cut stays aligned with the attack's
captured direction. Completion or cancellation restores Idle_A and Model yaw.
Death releases the melee pose to Death_A while preserving the immediate died
signal and combat/collision shutdown.

`weapons/axe_2handed.gltf`, its binary and texture are unmodified assets from the
same Adventurers FREE 2.0 pack (covered by this folder's `License.txt`). The axe is
attached to `handslot.r` by a BoneAttachment3D, and follows the two-handed clip.
Only this Boss's old three procedural sword meshes are hidden; the existing
range preview remains active. The axe is visual only and adds no collision.

The Boss's separate 1.0-second RECOVER counterattack window, 2.2-second attack
cooldown, sector query, damage, range, obstruction checks, charge and exit flow
remain unchanged. Player and ordinary enemy presentation are unaffected.

## Charge running presentation

`scenes/bosses/boss_charge_animation.gd` listens to the existing Boss
`state_changed` signal and reads its actual State enum. It starts the looping
`locomotion/Running_A` only on entry to CHARGE, after the existing charge windup.
On leaving CHARGE, it returns to Idle_A with a 0.10-second visual blend. Ordinary
damage does not restart the run; death pauses the current action instead of
starting idle. The existing two-handed melee controller remains unchanged.

The clip already exists in the shared CC0 `../animations/locomotion.tres`,
extracted from Character Animations FREE 1.1
`Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb`. Its original 0.8-second
loop plays at 1x on the physics animation callback, stopping whenever the real
charge stops, even before one full cycle. No new animation asset is needed.

All tracks target the character skeleton; the charge presentation node never
writes actor velocity, position, facing, Model transforms, timers, collision or
combat state. Physical displacement stays exclusively in the original Boss
`_move_charge()` and `move_and_slide()`. The 1-second warning, locked direction,
12m/s speed, maximum 7m travel, wall/player collision, single contact damage,
warning/trail lifecycle, cooldowns and 1-second recovery remain unchanged.

## Accepted damage and locomotion presentation

`scenes/bosses/boss_hit_animation.gd` listens to the existing `damage_received`
signal, which is emitted only after accepted HP loss. It reuses the shared CC0
`../animations/hit.tres` non-looping `Hit_A` (0.666667 seconds, original Rig_Medium
General skeleton tracks) at 1x speed. Fatal damage skips Hit_A because the Boss
sets its dead flag before emitting damage_received. Ignored damage never starts
or restarts a reaction; a new accepted nonfatal hit can restart an allowed Hit_A.

SWING (including its full recovery), CHARGE_WINDUP and CHARGE take precedence.
Hits during these actions keep the existing flash but skip Hit_A; no reaction
is queued for later. If an action starts during Hit_A, the reaction yields
immediately without cancelling or delaying combat. HitAnimation is placed before
the existing melee/charge presentation nodes, so its signal handlers release
manual sampling before an action captures the animation callback mode. Death
also cancels Hit_A without restoring locomotion or delaying the existing died
signal and exit flow.

After a complete reaction, the controller reads current state and actual
horizontal `get_real_velocity()`: moving CHASE uses the existing shared Walking_A,
while stopped/blocked CHASE, DORMANT and RECOVER use Idle_A. It keeps this fallback
locomotion current outside higher-priority actions. The existing charge controller
still exclusively owns Running_A during CHARGE. Pausing the dungeon freezes the
reaction; leaving the scene creates no delayed completion callback.

This is presentation only. No hurt state, stun, knockback, new invulnerability,
damage, state transition, movement, cooldown or counterattack-window change is
introduced. Living Boss AI, melee/charge controller behavior, shared animation
resources, other characters, HP/flash/UI and progression logic remain unchanged.

## Full Boss death presentation

`scenes/bosses/boss_death_animation.gd` uses the shared CC0
`../animations/death.tres` non-looping Death_A: the original complete 0.8-second
Rig_Medium General clip, at 1x. This last scene node subscribes to died after the
hit, melee and charge handlers release the skeleton, then manually samples the
death clip from time zero through its exact final pose. Bone poses are reset
before playback so omitted constant tracks cannot retain an earlier action.
A physics delta that
predates a same-tick lethal hit is not counted toward the new animation.

RuinGatekeeper retains its existing zero-HP/dead flag, DEAD state, immediate AI
and attack shutdown, deferred safe collision disabling, warnings/trail hiding,
zero velocity, HP/flash signals and immediate died emission. Only the old three
lines creating the 0.5-second Visuals squash/queue_free tween were removed from
its script. No combat values or living-state behavior were changed.

The final Death_A pose emits DeathAnimation.death_finished once; the scene
connects that to the actor's queue_free(), removing the Boss and model only after
the full action. There is no competing timer or squash. Main still receives died
immediately to show the existing defeated bar and start opening the exit at the
original time. Pausing the dungeon pauses the death pose/time; restart creates a
fresh full-health Boss with Idle_A and no pending death completion.
