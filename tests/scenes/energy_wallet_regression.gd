extends SceneTree
## Isolated regression; never reads or writes the real player profile.
const Profile = preload("res://scripts/integration/player_profile.gd")
const Player = preload("res://scenes/player/Player.tscn")
const Factory = preload("res://addons/ziyuan_level03/factory.gd")
const Catalog = preload("res://addons/ziyuan_level03/catalog.gd")
const SAVE := "res://.godot/energy-wallet-roundtrip.cfg"
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	Profile.override_path = SAVE
	if "--readback" in OS.get_cmdline_user_args():
		Profile.ensure_loaded()
		check(Profile.coins == 77 and Profile.owns("lan") and Profile.get_selected_character() == "lan", "new process restores wallet, ownership and selection")
		check(Profile.settle_run("durable-win",77) and Profile.coins == 77, "new process rejects duplicate settlement")
	else:
		test_wallet()
		await test_resources()
	root.get_node("MusicManager").stop_music()
	print("ENERGY_WALLET_RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_wallet() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE+suffix): DirAccess.remove_absolute(SAVE+suffix)
	var initial := ConfigFile.new()
	initial.set_value("profile","coins",100)
	initial.set_value("metadata","keep","existing setting")
	check(initial.save(SAVE) == OK, "isolated legacy wallet created")
	Profile.ensure_loaded()
	check(Profile.unlock_character("lan") and Profile.set_selected_character("lan"), "purchase and selection persist")
	check(Profile.settle_run("durable-win",77) and Profile.coins == 77, "settlement credits remaining run coins")
	check(Profile.settle_run("durable-win",77) and Profile.coins == 77, "settlement is idempotent")
	var config := ConfigFile.new()
	config.load(SAVE)
	check(config.get_value("metadata","keep") == "existing setting" and config.get_value("profile","coins") == 77, "atomic replacement preserves existing settings and writes real balance")
	check(not FileAccess.file_exists(SAVE+".tmp") and FileAccess.file_exists(SAVE+".bak"), "completed save leaves recovery backup without a temporary file")
	# Backup the confirmed balance too, then emulate a truncated primary file.
	check(Profile.save(), "confirmed profile can be saved again")
	var broken := FileAccess.open(SAVE,FileAccess.WRITE)
	broken.store_string("[truncated")
	broken.close()
	Profile._loaded_path = ""
	Profile.ensure_loaded()
	check(Profile.coins == 77 and Profile.owns("lan") and "durable-win" in Profile.settled_runs, "truncated primary recovers the valid wallet and settlement ledger")
	check(Profile.save(), "recovered profile repairs primary")
	config.load(SAVE)
	check(config.get_value("metadata","keep","") == "existing setting", "repair also preserves unrelated backup settings")
	var missing := "res://.godot/no-wallet-directory-%d/profile.cfg" % Time.get_ticks_usec()
	Profile.override_path = missing
	Profile._loaded_path = missing
	check(not Profile.set_coins(99) and Profile.coins == 77, "failed balance write rolls memory back")
	check(not Profile.set_coins(99) and Profile.coins == 77, "retry of same failed amount cannot falsely report success")
	check(not Profile.settle_run("failed-win",12) and Profile.coins == 77 and "failed-win" not in Profile.settled_runs, "failed settlement rolls back both balance and receipt")
	Profile.override_path = SAVE
	Profile._loaded_path = SAVE
	check(Profile.save(), "confirmed wallet ready for separate-process readback")

func test_resources() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	for id in ["knight","lan","iron","astra"]:
		var actor := Player.instantiate()
		actor.character_id = id
		stage.add_child(actor)
		actor.set_physics_process(false)
		actor.get_node("CharacterAbility").set_physics_process(false)
		var before: float = actor.energy
		check(actor.spend_energy(5), id+" spends five energy")
		for i in 100: actor._physics_process(0.1)
		check(actor.energy == before-5, id+" has no continuous recovery after ten seconds")
		check(actor.restore_energy(999) == 5 and actor.energy == actor.max_energy, id+" explicit recovery clamps at maximum")
		check(actor.restore_energy(10) == 0, id+" full energy cannot repeatedly consume recovery")
		actor.free()
	var target := Player.instantiate()
	stage.add_child(target)
	target.set_physics_process(false)
	target.position = Vector3(1000,0,1000)
	for id in Catalog.ENEMIES:
		var enemy := Factory.create(id,target)
		stage.add_child(enemy)
		enemy.set_encounter_active(true)
		enemy.set_physics_process(false)
		check(enemy.take_damage(1), id+" takes damage")
		var remaining: int = enemy.hp
		for i in 100: enemy._physics_process(0.1)
		check(enemy.hp == remaining, id+" health does not regenerate during ten seconds")
		enemy.free()
	stage.free()
	await process_frame
