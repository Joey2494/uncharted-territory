# MeleeEnemy Skeleton Warrior

- Author: Kay Lousberg — https://www.kaylousberg.com/
- Official source: https://kaylousberg.itch.io/kaykit-skeletons
- Character pack: KayKit Skeletons FREE 1.1.
- Source model: `characters/gltf/Skeleton_Warrior.glb`, copied without changes on 2026-11-03.
- License: CC0, preserved in `License.txt`.

`scenes/enemies/MeleeEnemy.tscn` instances the character inside `Visuals/Model`. This independent wrapper rotates the imported +Z facing to the AI's -Z facing and scales it by 0.618, approximately fitting the original 1.6 m capsule. CharacterBody3D, collision, Visuals orientation, AI and the existing procedural attack weapon/range preview remain authoritative. No new attack animation, weapon collider, shield blocking or root-motion movement is added.

`animations/warrior.tres` contains only Idle_A, Running_A, Hit_A and Death_A from KayKit Character Animations FREE 1.1's Rig_Medium General and MovementBasic files. It preserves original bone tracks; idle/run loop, hit/death do not. The animation pack's CC0 license is preserved in `animations/License.txt`. Source rigs were previously checked against all 23 Skeleton_Warrior bones, including names, hierarchy and rest transforms.

`scenes/enemies/melee_enemy_animation.gd` owns presentation. Idle/run selection reads actual physical velocity, so a blocked enemy returns to Idle_A. Hit_A is manually sampled against MeleeEnemy's existing hurt countdown: the complete 0.666667 s source clip fits the default 0.18 s hurt window, without extending the AI stun or using another timer. Repeated accepted damage restarts the same presentation clock; fatal hits skip Hit_A and immediately select Death_A.

Death still immediately stops AI/attacks, disables collision and emits the original died signal. Only the old 0.3 s visual squash and deletion tween were removed from MeleeEnemy.gd. The presentation plays the complete 0.8 s Death_A at 1x, applies its final pose and emits death_finished; the scene connects that signal to queue_free(). Parent pause/freeze and scene reload naturally govern the animation and its cleanup. A fresh scene instance initializes Idle_A even before the start menu enables the dungeon.

Godot may extract the embedded `skeleton_texture` PNG during import; keep the generated texture/import files alongside the GLB. This integration does not modify player, Boss, shared melee, skills, damage or UI resources.
