extends SceneTree

## B37 / GDD-16 fase 4: Vida da montaria própria, Elo que cai com golpe forte e sobe ao escapar
## junto, vila segura, morte permanente (sai do save) e a Lembrança com o trait Saudade.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const DT: float = 1.0 / 30.0

## Zona de teste: tudo é vila (segura) quando `city` está ligado
class FakeZones extends Node:
	var city: bool = false
	func can_combat_at(_pos: Vector3, _in_duel: bool = false) -> bool:
		return not city

var _started: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("💔 TESTANDO VIDA E MORTE DA MONTARIA (B37)")
	print("========================================================")
	var player: Player = PlayerScene.instantiate() as Player
	root.add_child(player)
	player._setup_components()
	player.set_physics_process(false) # sem chão no teste
	var eco := EcosystemSpawner.new()
	for prop in ["trotador_herds", "saltarelos", "planadores", "raias", "lambari_schools", "trees", "bushes", "cepas", "mushrooms", "pinheira_groves"]:
		eco.set(prop, 0)
	root.add_child(eco)
	var zones := FakeZones.new()
	zones.add_to_group("zone_manager")
	root.add_child(zones)
	test_health_and_zones(player, eco, zones)
	test_bond_in_combat(player, eco)
	await test_permanent_death(player, eco)
	test_forge_saudade()
	test_item_memory(player)
	print("\n🎉 TODOS OS TESTES DE VIDA E MORTE DA MONTARIA PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _hit(target: Node, dmg: float, attacker: Node = null) -> float:
	var hit := HitEvent.new(attacker, target, dmg, DamageType.Type.SLASH, 0.0, &"body")
	return float(CombatResolver.resolve_hit(hit).get(&"effective_damage", 0.0))

func test_health_and_zones(player: Player, eco: EcosystemSpawner, zones: FakeZones) -> void:
	print("\n[1/5] Vida e zona segura...")
	var dna := CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 41)
	dna.alleles["porte"] = ["T", "T"]
	dna.alleles["indole"] = ["I", "i"]
	assert(eco.add_owned_mount(dna, MountBond.create(dna, &"cria", 0)), "Montaria própria")
	var m: Mount = eco._owned_nodes[0]
	assert(m.pools != null and m.get_node_or_null("BodyHurtbox") is HurtboxComponent, "Montaria própria tem Vida e hurtbox")
	assert(is_equal_approx(m.stats.get_stat(&"max_health"), WildCreature.HEALTH[CreatureDNA.Species.TROTADOR]), "Vida da tabela dos bichos (TT = 100%)")
	var test_mount := Mount.new()
	test_mount.dna = CreatureDNA.randomized(CreatureDNA.Species.TROTADOR, 42)
	root.add_child(test_mount)
	assert(test_mount.pools == null, "Montaria de teste do estábulo não tem Vida")
	test_mount.queue_free()
	zones.city = true
	assert(_hit(m, 30.0) == 0.0 and m.pools.current_health == m.stats.get_stat(&"max_health"), "Na vila não toma dano")
	zones.city = false
	assert(_hit(m, 30.0) > 0.0, "Fora da vila toma dano")
	assert(_hit(m, 30.0, player) == 0.0, "O próprio dono não a fere")
	m.pools.heal(9999.0)
	print("  ✓ Vida %d, vila segura, sem dano do dono" % roundi(m.stats.get_stat(&"max_health")))

func test_bond_in_combat(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[2/5] Elo em combate...")
	var m: Mount = eco._owned_nodes[0]
	var elo0 := m.bond.elo
	_hit(m, 5.0)
	assert(m.bond.elo == elo0, "Sem cavaleiro, golpe não mexe no Elo")
	m.mount(player)
	_hit(m, 5.0)
	assert(m.bond.elo == elo0, "Arranhão (< 10% da Vida) não tira Elo")
	_hit(m, 20.0)
	assert(m.bond.elo == elo0 - 2.0, "Golpe forte com o dono montado: −2 (Equilibrada)")
	for i in roundi(Mount.ESCAPE_SECONDS / DT) + 5:
		m._physics_process(DT)
	assert(m.bond.elo == elo0, "20 s sem apanhar, ainda montados: escaparam juntos (+2)")
	_hit(m, 20.0)
	m.dismount()
	for i in roundi(Mount.ESCAPE_SECONDS / DT) + 5:
		m._physics_process(DT)
	assert(m.bond.elo == elo0 - 2.0, "Desmontou antes: não conta como fuga")
	m.pools.heal(9999.0)
	print("  ✓ Golpe forte −2, fuga junto +2")

func test_permanent_death(player: Player, eco: EcosystemSpawner) -> void:
	print("\n[3/5] Morte permanente...")
	var second := CreatureDNA.randomized(CreatureDNA.Species.PLANADOR, 43)
	assert(eco.add_owned_mount(second), "Segunda montaria")
	var m: Mount = eco._owned_nodes[0]
	m.bond.rename("Estrela")
	m.set_bond(m.bond)
	assert(eco.set_companion(m), "Companheira")
	m.global_position = Vector3(30, 0, 30)
	m.mount(player)
	_hit(m, 9999.0)
	assert(m.dead and player.mounted_on == null, "Morreu e derrubou o dono")
	assert(eco.owned.size() == 1 and eco.bonds.size() == 1 and eco._owned_nodes.size() == 1, "Saiu do estábulo")
	assert(eco.owned[0] == second and eco.companion_mount() == null, "Ficou só a outra; sem Companheira")
	var state: Array = eco.owned_state()
	assert(state.size() == 1, "E saiu do save (não volta no load)")
	assert(m.is_queued_for_deletion(), "O nó some")
	await process_frame
	var loots := get_nodes_in_group("dropped_loot")
	assert(loots.size() == 1, "Deixou uma trouxa no chão")
	var loot: DroppedLoot = loots[0]
	assert(loot.stack.id == &"lembranca" and loot.stack.quality == 3 and loot.stack.traits.has(&"saudade"), "A Lembrança: 3★ com Saudade")
	assert(Vector2(loot.global_position.x, loot.global_position.z).distance_to(Vector2(30, 30)) < 0.5, "No lugar do corpo")
	assert(loot.stack.memory.name == "Estrela" and loot.stack.memory.species == "Trotador" and loot.stack.memory.kind == "lembranca", "A Lembrança guarda o nome e a espécie")
	assert(loot.next_harvest_label().contains("Lembrança de Estrela"), "O chão mostra de quem é")
	loot.talk_to(player)
	assert(player.inventory.get_material_count(&"lembranca") == 1, "Qualquer um pega com [E] (o dono, aqui)")
	assert(player.inventory.best_stack(&"lembranca").memory.name == "Estrela", "Na mochila o nome continua")
	print("  ✓ Morreu de vez, saiu do save e deixou a Lembrança")

func test_forge_saudade() -> void:
	print("\n[4/5] Saudade na forja...")
	var core := {"id": &"pena_penacho", "quality": 3, "traits": [], "amount": 3}
	var coat := {"id": &"fibra", "quality": 3, "traits": [], "amount": 4}
	var temper := {"id": &"lembranca", "quality": 3, "traits": [&"saudade"], "amount": 1}
	var p := Forge.preview(&"capuz_penacho", core, coat, temper, Forge.TEMPER_LEVEL, false)
	assert(p.ok and p.traits.has(&"saudade"), "Lembrança como tempero de armadura dá Saudade")
	assert(Forge.TRAIT_BONUS[&"saudade"][&"resist_impact"] == 0.05, "Saudade: +5% de resistência")
	var weapon := Forge.preview(&"espada_ferro", {"id": &"barra_ferro", "quality": 3, "traits": [], "amount": 2}, {"id": &"fibra", "quality": 3, "traits": [], "amount": 2}, temper, Forge.TEMPER_LEVEL, false)
	assert(not weapon.get("traits", []).has(&"saudade"), "Arma não leva Saudade")
	print("  ✓ Saudade (+5% resistências) só em armadura")

func test_item_memory(player: Player) -> void:
	print("
[5/5] Memória dos itens...")
	var inv := player.inventory
	var luar := {"kind": "lembranca", "name": "Luar", "species": "Planador-de-Penacho", "elo": 90, "day": 7}
	inv.add_material(&"lembranca", 1, 3, [&"saudade"], luar)
	assert(inv.get_material_count(&"lembranca") == 2 and inv.get_stacks(&"lembranca").size() == 2, "Lembranças de montarias diferentes não se juntam")
	inv.add_material(&"lembranca", 1, 3, [&"saudade"], luar.duplicate())
	assert(inv.get_stacks(&"lembranca").size() == 2, "Mesma memória junta na mesma pilha")
	inv.add_material(&"fibra", 2)
	assert(not inv.best_stack(&"fibra").has("memory"), "Pilha sem história continua sem a chave")
	assert(MaterialData.memory_text(luar) == "Lembrança de Luar (Planador-de-Penacho, Elo 90, dia 7)", "Texto da memória")
	# Save e load
	var saved: Array = JSON.parse_string(JSON.stringify(inv.stacks_to_save()))
	inv.load_from_save(saved)
	var names: Array = inv.get_stacks(&"lembranca").map(func(st): return st.memory.name)
	names.sort()
	assert(names == ["Estrela", "Luar"], "O save guarda as memórias (%s)" % [names])
	# Jogar no chão leva a memória junto
	var luar_stack: Dictionary = inv.get_stacks(&"lembranca").filter(func(st): return st.memory.name == "Luar")[0]
	var dropped := inv.drop_stack(luar_stack, 1)
	assert(dropped.memory.name == "Luar", "No chão a memória vai junto")
	inv.add_material(dropped.id, dropped.amount, dropped.quality, dropped.traits, dropped.memory)
	# Forja: a peça herda a memória e o nome
	inv.add_material(&"pena_penacho", 3, 3)
	inv.add_material(&"fibra", 4, 3)
	var estrela: Dictionary = inv.get_stacks(&"lembranca").filter(func(st): return st.memory.name == "Estrela")[0]
	var rng := RandomNumberGenerator.new()
	var item := Forge.forge(inv, &"capuz_penacho", inv.best_stack(&"pena_penacho"), inv.best_stack(&"fibra"), estrela, Forge.TEMPER_LEVEL, false, rng)
	assert(item != null and item.traits.has(&"saudade"), "Forjou com a Lembrança")
	assert(item.memory.name == "Estrela" and item.display_name.ends_with("Saudade de Estrela"), "A peça leva o nome dela: %s" % item.display_name)
	assert(inv.get_stacks(&"lembranca").size() == 1 and inv.best_stack(&"lembranca").memory.name == "Luar", "Gastou a Lembrança certa")
	var back := ForgedItem.from_dict(JSON.parse_string(JSON.stringify(item.to_dict())))
	assert(back.memory.name == "Estrela" and back.display_name == item.display_name, "A peça guarda a memória no save")
	print("  ✓ Memória separa pilhas, vai para o chão, o save e a peça forjada")
