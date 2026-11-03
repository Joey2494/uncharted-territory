# KayKit Knight

- Author: Kay Lousberg — https://www.kaylousberg.com/
- Source: https://kaylousberg.itch.io/kaykit-adventurers
- Pack: KayKit Adventurers FREE 2.0
- Original file: `Characters/gltf/Knight.glb`
- License: CC0 1.0 Universal; the original pack license is preserved in `License.txt`.
- Imported on: 2026-11-02

`Knight.glb` is an unmodified, rigged character with an embedded texture. It has no embedded animation clips. Three locomotion clips and a player-only single-handed diagonal slash are provided separately in `animations/locomotion.tres` and `animations/melee.tres`; see that folder's README and license. `weapons/` contains the same-pack one-handed sword for the player's right-hand bone attachment.

Godot extracts `Knight_knight_texture.png` during import. Keep that texture and the generated `.import` settings alongside the GLB.

`scenes/player/Player.tscn` instances it under `Visuals/Model`. The wrapper scales it by 0.71 and rotates it 180 degrees around Y to map the asset's +Z facing direction to the player's local -Z. The source mesh has its feet at Y=0, so no vertical offset is applied. The locomotion controller reads actual player movement; it never rotates or displaces the physics body or model wrapper.
