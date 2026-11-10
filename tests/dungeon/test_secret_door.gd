extends SceneTree
## 在真实主场景验证解谜、门体、物理通路及新揭示地面的共面重叠。
var checks := 0
var failures := 0
func _initialize() -> void:
    run.call_deferred()
func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        print("FAIL: ", message)
func wait_frames() -> void:
    await physics_frame
    await physics_frame
func blocked(d: Node3D, player: Node3D) -> bool:
    var q := PhysicsRayQueryParameters3D.create(Vector3(-26, 1, -29), Vector3(-26, 1, -33), 1, [player.get_rid()])
    return not d.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func floor_rect(region: Node3D) -> Rect2:
    var mesh: MeshInstance3D = region.get_node("Geometry/Floor/MeshInstance3D")
    var bounds: AABB = mesh.global_transform * mesh.get_aabb()
    return Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
func run() -> void:
    var game = load("res://Main.tscn").instantiate()
    root.add_child(game)
    game._on_run_started()
    var d = game.get_node("DungeonTest")
    var p = d.get_node("Player")
    var puzzle = d.get_node("RunePuzzle")
    p.position = Vector3(-26, 0.05, -28)
    await wait_frames()
    check(blocked(d, p), "暗门关闭时应阻挡射线")
    p.global_position = puzzle.get_node("SunRune").global_position + Vector3(0, 0.05, 1.2)
    await wait_frames()
    check(puzzle.activate_rune(0, p), "实际交互可触发错误顺序")
    check(puzzle.state == puzzle.State.RESETTING, "错误顺序进入复位")
    await create_timer(0.8).timeout
    check(puzzle.state == puzzle.State.READY, "错误后可以重试")
    for entry in [[1, "MoonRune"], [2, "StarRune"], [0, "SunRune"]]:
        p.global_position = puzzle.get_node(entry[1]).global_position + Vector3(0, 0.05, 1.2)
        await wait_frames()
        check(puzzle.activate_rune(entry[0], p), "符文实际交互 " + entry[1])
        if entry[0] != 0: await create_timer(0.25).timeout
    check(puzzle.state == puzzle.State.OPENING, "正确顺序开始开门")
    check(blocked(d, p), "开门期间保留碰撞")
    await create_timer(0.2).timeout
    d.process_mode = Node.PROCESS_MODE_DISABLED
    var height: float = puzzle.get_node("HiddenDoor/MeshInstance3D").position.y
    await create_timer(1.0).timeout
    check(is_equal_approx(height, puzzle.get_node("HiddenDoor/MeshInstance3D").position.y), "暂停冻结门动画")
    check(puzzle.state == puzzle.State.OPENING, "暂停不提前完成开门")
    d.process_mode = Node.PROCESS_MODE_INHERIT
    await create_timer(1.0).timeout
    await wait_frames()
    check(puzzle.is_solved(), "恢复后完成开门")
    check(not puzzle.get_node("HiddenDoor").is_visible_in_tree(), "完整门体隐藏")
    check(not blocked(d, p), "开启后物理通路畅通")
    check(d.get_room_count() == 6, "隐藏区域加入探索")
    var a = d.get_node("Regions/SecretPassage")
    var b = d.get_node("Regions/HiddenRewardRoom")
    var overlap := floor_rect(a).intersection(floor_rect(b))
    print("FLOOR_OVERLAP_AREA=", overlap.get_area())
    check(overlap.get_area() < 0.001, "门后走廊和奖励房间不得有共面可见地板重叠")
    check(is_equal_approx(a.get_node("Geometry/Floor/CollisionShape3D").shape.size.z, a.dimensions.y + 1.2), "物理地板保持原有连续接缝")
    p.position = Vector3(-26, 0.05, -29.4)
    await wait_frames()
    p.move_and_collide(Vector3(0, 0, -4))
    check(p.position.z < -33, "玩家实际碰撞移动可穿过已开启暗门")
    p.position = Vector3(-26, 0.05, -39.5)
    await wait_frames()
    check(puzzle.claim_reward(p), "可领取真实宝箱奖励")
    check(not puzzle.claim_reward(p), "奖励不能重复领取")
    game.queue_free()
    await process_frame
    game = load("res://Main.tscn").instantiate()
    root.add_child(game)
    game._on_run_started()
    await wait_frames()
    puzzle = game.get_node("DungeonTest/RunePuzzle")
    check(puzzle.state == puzzle.State.READY, "新一局重置谜题")
    check(puzzle.get_node("HiddenDoor").visible, "新一局恢复门体")
    check(not puzzle.get_node("HiddenDoor/CollisionShape3D").disabled, "新一局恢复碰撞")
    game.queue_free()
    await process_frame
    print("SECRET_DOOR: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
