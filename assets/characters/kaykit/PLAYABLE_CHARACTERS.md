# Playable Rogue and Mage

Author: Kay Lousberg. Source: [official KayKit Adventurers repository](https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0), directory `addons/kaykit_character_pack_adventures/Characters/gltf/`.

Imported on 2026-11-10. `Rogue.glb` and `Mage.glb` are unmodified official free-pack downloads. License: CC0 1.0, matching the original `License.txt` retained in this directory. Godot extracts the corresponding PNG textures during import.

The GitHub pack is the earlier Adventurers 1.0 release. The existing Knight is from Free 2.0. Both use the shared named humanoid bones; the older pack also includes IK bones. Runtime code in `scenes/player/character_catalog.gd` renames the imported Rig wrapper to Rig_Medium, removes embedded AnimationPlayers, and hides optional weapons. Source files remain intact. Existing shared player animation libraries drive the resulting Skeleton3D.

The Knight-named wrapper is deliberately preserved for existing player animation paths. Rogue is Lan and Mage is Astra; the free traveler retains the original Knight model.

Following the requested role swap, Iron uses `IronGuard.tscn` with the original CC0 Free 2.0 Barbarian body (the former first-level Boss appearance), plus locally authored steel armor and a round shield from `iron_guard_visual.gd`. Menu and gameplay use the same model; the original starting Knight remains unchanged.

The previous bespoke bronze sentinel now belongs to the first-level Boss, through `BronzeGatekeeper.tscn` and `bronze_gatekeeper_visual.gd`. Its visible geometry is locally authored. It uses `iron_guard_rig.tscn`, a mesh-free copy of the shared 23 named bones/rest poses, for the original Boss's melee, hit, charge and death animation interfaces. The GLB source files are unchanged. The Boss folds its shield during two-handed axe swings and changes visor color during charge warnings.

The `Barbarian` node name in the Boss scene and `Knight` node name in the player scene remain compatibility paths; actual appearances are determined by the model resources above.

The player sword remains the melee fallback. Firearms are integrated separately; magazines, reload buffs and weapon-specific casting presentation remain future extensions.
