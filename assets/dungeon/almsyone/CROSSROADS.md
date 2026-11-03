# AlmsyONE courtyard visuals

The independent `scenes/dungeon/Crossroads.tscn` extends the unchanged original
region generator. Only the Crossroads instance in DungeonTest uses it. Original
physics, 18 x 14 m bounds, three 5 m-wide routes, wayfinding, lighting, enemy
placement, AI and combat remain unchanged. EntranceHall is unchanged.

Six unchanged source GLBs augment the existing common modules:
SM_Floor_Stone_Cracked, SM_Floor_Stone_Mossy, SM_Wall_Mossy, SM_Pillar_Broken,
SM_Rubble and SM_Banner_Red. Source and terms are in ORIGINAL_README.txt.

M_Stone* and M_Moss material instances use RGB x 0.40, matching the entrance's
dark stone palette. Original materials and GLBs are never edited. Floor variants
use deterministic placement and MultiMesh batches, fit the existing overlap slab,
and keep even cracked upper edges 2 mm below the original physical ground.

Broken pillars and rubble stay at the perimeter; central combat and three routes
remain clear. No decoration adds collision, navigation, lights or interaction.
Wall/decor meshes are single-surface children of the original camera occluders,
preserving the existing camera's material fade and restoration.

The existing enemy's eastern combat area also uses the ordinary-combat selection:
SM_Wall_Cracked, SM_WeaponRack, SM_Barrel_Broken, SM_Crate_Small, SM_Bones_Pile,
SM_Wall_CellBars and SM_Cage. Seven additional floor cells around that area use
the already-imported cracked floor, without changing the other floor cells.
Only two north-wall modules and two southeast-wall modules change to cracked
stone. The original moss, pillars, rubble, torches and banners remain in place.

Eight decorative instances form the perimeter combat dressing: two background
bar panels against existing solid walls, one weapon rack, one cage, two bone
piles, one broken barrel and one small crate. They leave all three 5 m-wide
routes and the central combat floor clear. Bars and cage remain purely visual;
original physics, sight checks, attacks and projectile collision are unchanged.
