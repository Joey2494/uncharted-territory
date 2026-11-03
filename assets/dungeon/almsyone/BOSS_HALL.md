# AlmsyONE Boss hall

Only BossArena uses BossHall.tscn. The original region generator still owns all
floor/wall bodies, layers, shapes, dimensions (22 x 20 m) and west/north openings.
Boss spawn, AI, animations, warning meshes, attacks, charge movement/collision,
death and exit unlock remain unchanged.

SM_Throne and SM_Brazier are unchanged new source GLBs. Existing SM_Banner_Red,
SM_Statue_Knight, floor/wall/corner/pillar and broken-pillar models are reused.
Stone instances use RGB x 0.40. Brazier fire emission uses 0.35 to retain flame
colour under the existing lighting. Original files/materials are not modified.

The throne sits against the east wall, clear of the west entrance and north
exit. Six red banners, four braziers, four statues, four doorway pillars and two
broken pillars stay around the perimeter. Solid dressing stays outside the
central 17.6 x 15.6 m rectangle and outside a 7 m charge plus capsule radius
around the original spawn. No decorative collision, lights, navigation or
interaction is added. Existing wayfinding and lighting remain unchanged.

110 floor tiles use six MultiMesh surface batches: 102 plain tiles and eight
cracked edge tiles. Their tops remain 2 mm below the original physical floor.
Wall/decor meshes remain single-surface children of original camera occluders.
