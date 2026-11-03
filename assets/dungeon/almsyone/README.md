# AlmsyONE dungeon assets

Source: https://almsyone.itch.io/low-poly-fantasy-dungeon-kit

Pack: Low Poly Fantasy Dungeon Kit v1.0, AlmsyONE. Imported 2026-11-03.
The thirty-six GLB files are unchanged originals from the 87-model pack. The original
README, including personal/commercial-use and raw-file redistribution terms, is
preserved in `ORIGINAL_README.txt`. This pack is not CC0.

`scenes/dungeon/EntranceHall.tscn`, `scenes/dungeon/Crossroads.tscn`,
`scenes/dungeon/PuzzleChamber.tscn`, `scenes/dungeon/BossHall.tscn` and
`scenes/dungeon/ExitChamber.tscn` use these
assets. Their dedicated tool scripts
extend the original region, let it generate
the exact existing floor and wall collision bodies, then replace their visible
meshes and add decorative models. The shared region generator, other rooms,
player spawn, items, route markers, doorway labels, exit, lighting and gameplay
scripts remain unchanged. Courtyard-specific assets and layout are documented in
`CROSSROADS.md`; puzzle-room assets and visual-only rune followers are documented
in `PUZZLE_CHAMBER.md`.
Boss hall dressing and preserved battle clearance are documented in `BOSS_HALL.md`.
Exit frames, gate presentation and preserved victory flow are documented in `EXIT.md`.

Stone material instances (`M_Stone*`) are uniformly multiplied by 0.40; the
courtyard also applies this brightness to `M_Moss`. Source materials and GLBs are
never modified. Entrance floor rendering uses three MultiMeshes
with 80 instances each, fitted to the original overlap slab, 2mm below physics to
avoid coplanar overlaps with the unchanged adjoining regions.

Wall and prop geometry is split into single-surface MeshInstance3D children under
the original camera_occluders wall bodies. This preserves each material colour
with the unchanged camera's per-mesh alpha fade in Compatibility rendering.
New decorative geometry has no collision or gameplay behavior. Existing 5m
doorways remain open; the original navigation frames and labels stay in place.
