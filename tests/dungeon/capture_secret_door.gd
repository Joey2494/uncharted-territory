extends SceneTree
## 可重复的真实渲染诊断：以实际关卡观察暗门与相邻地面。
var game: Node
var output := "user://door_review"
var window_size := Vector2i(1280, 720)
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
        if arg == "--full-hd": window_size = Vector2i(1920, 1080)
    DirAccess.make_dir_recursive_absolute(output)
    run.call_deferred()
func shot(label: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join(label + ".png"))
func run() -> void:
    game = load("res://Main.tscn").instantiate()
    root.add_child(game)
    root.size = window_size
    game._on_run_started()
    var dungeon = game.get_node("DungeonTest")
    var player = dungeon.get_node("Player")
    player.position = Vector3(-26, 0.05, -28)
    dungeon.get_node("Camera3D").reset_follow()
    await create_timer(0.4).timeout
    await shot("01_closed")
    dungeon.get_node("RunePuzzle")._open_hidden_room()
    await create_timer(0.45).timeout
    await shot("02_opening")
    await create_timer(0.65).timeout
    await shot("03_open")
    player.position.z = -32
    await create_timer(0.7).timeout
    await shot("04_threshold")
    player.position = Vector3(-24, 0.05, -35.8)
    await create_timer(0.7).timeout
    await shot("05_passage")
    print("CAPTURE_COMPLETE ", output)
    game.queue_free()
    await process_frame
    quit()
