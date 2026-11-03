# AlmsyONE return exit

ExitChamber.tscn replaces only the existing 12 x 8 m exit room appearance.
Original region physics, exploration data, lighting and the entire central 5 m
route remain unchanged. Stone instances use RGB x 0.40; blue crystals use the
existing helper's 0.12 emission to retain colour.

SM_Portcullis.glb is the only newly copied original GLB. Existing floor, wall,
corner, pillar, blue-crystal, blue-banner and standing-torch models are reused.
No decorative collision, navigation, lights or interaction is introduced.

ExitGate retains its original StaticBody3D, position, 5 x 3 x 0.6 m collision,
layer/mask, SealLabel and MeshInstance3D tween target. The old placeholder mesh
is excluded from render layers and shadows; its child Portcullis is fitted to
the original 5 x 3 m panel. Child rendering layers remain enabled independently.
The original 0.9 s / -3.6 m parent tween moves the new gate automatically.
There is no new gate state, animation, signal, timer or unlock path.

The fixed frame at the gate and the MapExit frame use native 0.8 m-wide,
3 m-high pillars centred at +/-2.9 m. A separate 6.6 x 0.3 x 0.8 m stone lintel
starts at Y=3.0 m, giving exactly 5 m clear width and 3 m clear height.
Frames stay visible after the moving gate is hidden. MapExit/Banner and all
original exit labels retain their paths and dynamic text updates.

ExitTrigger, PortalGlow, Boss defeat authorization, physical gate release,
victory checks, result UI, pause/restart and all existing scripts are unchanged.
