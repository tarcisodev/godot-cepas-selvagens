extends SceneTree

## Montaria terrestre atravessa o rio nadando (pedido do Tarciso): entra na água funda, boia com o
## dorso na linha d'água, nada devagar sem correr nem pular, gasta fôlego e sobe na outra margem.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

## Terreno de teste: leito fundo no rio (1,5 m abaixo da água), margem seca fora dele
class FakeLand extends Node:
	func get_height_at(x: float, z: float) -> float:
		var surface := RiverSystem.get_water_height(z)
		var d := RiverSystem.get_distance_to_river(x, z)
		return surface - 1.5 if d < RiverSystem.get_water_half_width(z) else surface + 0.4

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🐴 TESTANDO O NADO DA MONTARIA TERRESTRE")
	print("========================================================")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false)
	var mount := Mount.new()
	mount.kind = Mount.Kind.LAND
	mount.dna = CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 3)
	root.add_child(mount)
	mount._landscape = FakeLand.new()
	var z := -80.0
	var cx := RiverSystem.get_river_center_x(z)
	var half := RiverSystem.get_water_half_width(z)
	var start := Vector3(cx - half - 2.0, 0, z)
	mount.global_position = Vector3(start.x, mount._ground(start.x, z), z)
	mount.mount(player)

	# Atravessa o rio de margem a margem, de leste a oeste, empurrando para +X
	var surface := RiverSystem.get_water_height(z)
	var swam := false
	var swim_speed := 0.0
	for i in 600:
		mount._speed = Mount.SPEEDS[Mount.Kind.LAND].x * (Mount.LAND_SWIM_SPEED if mount.swimming else 1.0)
		var before := mount.global_position
		mount._move_land(Vector3(mount._speed / 60.0, 0, 0), 1.0 / 60.0, false)
		if mount.swimming:
			swam = true
			swim_speed = (mount.global_position.x - before.x) * 60.0
			assert(absf(mount.global_position.y - (surface - mount.body.back_height * 0.8)) < 0.01, "Boia com o dorso na linha d'água")
		if mount.global_position.x > cx + half + 2.0:
			break
	assert(swam, "Entrou no rio fundo nadando, em vez de travar na margem")
	assert(swim_speed < Mount.SPEEDS[Mount.Kind.LAND].x * 0.5, "Nada devagar (%.1f m/s)" % swim_speed)
	assert(mount.global_position.x > cx + half + 2.0 and not mount.swimming, "Saiu na outra margem e voltou a andar")
	assert(is_equal_approx(mount.global_position.y, mount._ground(mount.global_position.x, z)), "Pisando na margem seca")
	mount.dismount()
	mount._landscape.free()
	mount.free()
	player.free()
	print("  ✓ Entra no rio, boia, nada devagar e sobe na outra margem")
	print("\n🎉 TODOS OS TESTES DO NADO DA MONTARIA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)
