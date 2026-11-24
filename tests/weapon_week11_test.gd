extends SceneTree
const CATALOG = preload("res://scenes/weapons/weapon_catalog.gd")
var checks := 0
var failures := 0
class Target:
	extends CharacterBody3D
	var hp := 20
	var slow := 0.0
	func take_damage(amount: int) -> bool:
		hp -= amount
		return true
	func apply_slow(duration: float) -> void: slow = duration
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL ",message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60,1,60)
	shape.shape = box
	floor_body.add_child(shape)
	world.add_child(floor_body)
	floor_body.position.y = -0.5
	for id in CATALOG.LOADOUTS:
		var player := preload("res://scenes/player/Player.tscn").instantiate()
		player.character_id = id
		world.add_child(player)
		await frames(4)
		var weapons := player.get_node("WeaponLoadout")
		check(weapons.slots.size() == 2 and weapons.current().cost == 0,id+" zero-cost fallback")
		if id == "lan": player.get_node("CharacterAbility").prepared_remaining = 5.0
		check(weapons.try_attack(),id+" primary attack")
		if id == "lan": check(player.get_node("CharacterAbility").prepared_remaining > 0,"pistol does not consume prepared tactical shot")
		if weapons.current().melee:
			check(not weapons.try_switch(),"windup blocks switching")
			check(not player.try_dodge(),"windup blocks dodge")
		await frames(35)
		var primary_ammo: int = weapons.slots[0].ammo
		check(weapons.try_switch(),id+" tactical switch")
		check(not weapons.try_attack(),"switch takes 0.2s")
		await frames(14)
		player.energy = 0
		if id == "lan":
			check(weapons.try_attack(),"coil fires with empty mana")
			check(player.energy == 0,"coil does not consume mana")
			await frames(51)
		else:
			check(not weapons.try_attack(),"energy failure rejects shot")
			check(weapons.slots[1].cooldown == 0,"failure has no cooldown")
			player.energy = weapons.cost()-1
			check(not weapons.try_attack() and player.energy == weapons.cost()-1,"below new cost cannot fire or consume mana")
			player.energy = weapons.cost()
			check(weapons.try_attack() and player.energy == 0,"exact new cost permits the final shot")
			await frames(51)
		player.energy = player.max_energy
		var before: float = player.energy
		check(weapons.try_attack(),id+" tactical shot")
		if id == "lan": check(player.get_node("CharacterAbility").prepared_remaining == 0,"tactical shot consumes preparation")
		check(is_equal_approx(before-player.energy,4 if id == "astra" else (0 if id == "lan" else 5)),"correct tactical energy cost")
		check(weapons.slots[0].ammo == primary_ammo,"inactive magazine preserved")
		check(not weapons.try_attack(),"shot cadence")
		await frames(15)
		check(weapons.try_switch(),"recovery permits switching")
		await frames(14)
		check(not weapons.replace_current(CATALOG.state("fire")),"exclusive weapon cannot be replaced")
		if id == "lan":
			weapons.slots[0].ammo = 0
			check(not weapons.try_attack(),"empty pistol cannot fire")
			check(weapons.try_reload(),"reload starts")
			await frames(10)
			check(player.try_dodge(),"dodge cancels reload")
			check(weapons.reload_remaining == 0 and weapons.slots[0].ammo == 0,"reload cancellation preserves empty magazine")
			await frames(55)
			check(weapons.try_reload(),"reload restarts")
			await frames(10)
			var saved_reload: float = weapons.reload_remaining
			check(weapons.try_switch(),"switch may stow a reload")
			await frames(14)
			check(is_equal_approx(weapons.slots[0].reload,saved_reload),"stowed reload is paused")
			check(weapons.try_switch(),"return to reloading pistol")
			check(is_equal_approx(weapons.reload_remaining,saved_reload),"switch does not reset reload progress")
			await frames(78)
			check(weapons.slots[0].ammo == 8,"reload fills pistol magazine")
			var items := player.get_node("ItemInventory")
			check(items.pistol_ammo == 8,"only pistol reserve is spent")
			check(items.coil_ammo == 12,"pistol reload preserves coil reserve")
			weapons.slots[0].ammo = 0
			items.pistol_ammo = 0
			check(not weapons.try_replenish(),"coil reserve cannot reload pistol")
			check(weapons.try_switch(),"switch to coil")
			await frames(14)
			weapons.slots[1].ammo = 0
			items.pistol_ammo = 99
			items.coil_ammo = 3
			check(weapons.try_replenish(),"partial coil reload starts")
			await frames(95)
			check(weapons.slots[1].ammo == 3 and items.coil_ammo == 0,"partial reload uses only available coil ammo")
			check(items.pistol_ammo == 99,"coil reload preserves pistol reserve")
			items.pistol_ammo = 995
			items.gold = 100
			check(not items.try_purchase(6),"ammo cap refuses overfull purchase")
			check(items.gold == 100 and items.pistol_ammo == 995,"failed purchase leaves stock and gold unchanged")
			check(not items.grant_reward("overflow",{6:2,4:4}),"combined migrated ammo cannot overflow reserve")
			check(items.grant_reward("legacy_coil",{3:1}),"old firearm reward migrates into coil ammo")
			check(items.coil_ammo == 12 and not items.owns_firearm,"legacy reward does not grant a nonexclusive weapon")
		else:
			var items := player.get_node("ItemInventory")
			items.energy_potion_count = 2
			player.energy = player.max_energy-20
			items._use_remaining = 0
			if weapons.current().melee:
				check(not weapons.try_replenish(),"K on sword does not consume mana potion")
				check(weapons.try_switch(),"switch to staff")
				await frames(14)
			var before_mana: float = player.energy
			check(weapons.try_replenish(),"staff K consumes mana potion")
			check(is_equal_approx(player.energy,minf(player.max_energy,before_mana+20)),"K restores the same blue bar")
			check(items.energy_potion_count == 1,"one mana potion consumed")
			items._use_remaining = 0
			player.energy = player.max_energy
			check(not weapons.try_replenish() and items.energy_potion_count == 1,"full mana preserves potion")
		var health_items := player.get_node("ItemInventory")
		health_items._use_remaining = 0
		health_items.potion_count = 1
		player.hp = player.max_hp-1
		var event := InputEventKey.new()
		event.physical_keycode = KEY_R
		event.pressed = true
		check(event.is_action_pressed("use_health_potion"),"R remains health potion")
		health_items._unhandled_input(event)
		check(player.hp == player.max_hp and health_items.potion_count == 0,"R heals and consumes health potion")
		event.physical_keycode = KEY_K
		check(event.is_action_pressed("reload_weapon") and not event.is_action_pressed("skill_1"),"K is contextual replenishment only")
		check(not player.get_node("EnergyShock").try_cast(),"old K combat retired")
		player.queue_free()
		await frames(2)
	# Real swept projectile impacts, frost immunity and non-stacking delayed ember.
	for weapon in ["frost","fire"]:
		var source := CharacterBody3D.new()
		world.add_child(source)
		var target := Target.new()
		target.collision_layer = 4
		var collider := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.4
		collider.shape = sphere
		target.add_child(collider)
		world.add_child(target)
		target.position = Vector3(0,1,-2)
		for shot in 2:
			var bolt := preload("res://scenes/skills/EnergyBolt.tscn").instantiate()
			world.add_child(bolt)
			bolt.position.y = 1
			bolt.weapon_id = weapon
			bolt.launch(Vector3.FORWARD,2,18,10,source)
		await frames(15)
		check(target.hp == 16,"two direct impacts")
		if weapon == "frost": check(target.slow == 2.0,"frost slow is 2 seconds")
		else:
			check(target.get_child_count() == 2,"only one pending ember")
			await frames(62)
			check(target.hp == 15,"one delayed ember damage")
		target.queue_free()
		source.queue_free()
		await frames(2)
	world.queue_free()
	await frames(2)
	print("WEAPON_WEEK11_RESULT checks=%d failed=%d" % [checks,failures])
	quit(1 if failures else 0)
