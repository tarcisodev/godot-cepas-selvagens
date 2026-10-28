extends SceneTree

## B25: rótulo único do mundo (WorldLabel). Nome até 6 m, ícone de 6 a 15 m, nada além;
## só o [E] do alvo em foco aparece; placa até o alcance dela; `active` desliga.

const _WorldLabel = preload("res://scripts/ui/world_label.gd")
const _TownNPC = preload("res://scripts/town/town_npc.gd")

var _started: bool = false
var _viewer: Node3D

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🏷️ TESTANDO O RÓTULO ÚNICO DO MUNDO (B25)")
	print("========================================================")
	_viewer = Node3D.new()
	_viewer.add_to_group("player")
	root.add_child(_viewer)
	test_name_distances()
	test_prompt_focus()
	test_sign_and_active()
	test_town_npc_uses_world_label()
	print("\n🎉 TODOS OS TESTES DO RÓTULO ÚNICO PASSARAM COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _label_at(kind: int, txt: String, ico: String, pos: Vector3) -> _WorldLabel:
	var l := _WorldLabel.make(kind, txt, ico)
	root.add_child(l)
	l.global_position = pos
	return l

func _refresh(labels: Array) -> void:
	_WorldLabel._focus_frame = -1  # foco e jogador são lidos uma vez por quadro; aqui o quadro não anda
	_WorldLabel._viewer_frame = -1
	_WorldLabel._near_frame = -1
	for l in labels:
		l._update()

func test_name_distances() -> void:
	print("\n[1/4] Nome de perto, ícone no meio, nada de longe...")
	var l := _label_at(_WorldLabel.Kind.NAME, "Mercadora", "💰", Vector3(0, 2.2, 0))
	assert(l.font_size == _WorldLabel.FONT_SIZE and l.outline_size == _WorldLabel.OUTLINE, "Mesmo tamanho e contorno para todos")
	_viewer.global_position = Vector3(3, 0, 0)
	_refresh([l])
	assert(l.visible and l.text == "Mercadora" and l.modulate.a == 1.0, "A 3 m: nome inteiro")
	_viewer.global_position = Vector3(10, 0, 0)
	_refresh([l])
	assert(l.visible and l.text == "💰", "A 10 m: só o ícone")
	_viewer.global_position = Vector3(20, 0, 0)
	_refresh([l])
	assert(not l.visible, "A 20 m: nada")
	_viewer.global_position = Vector3(5.9, 0, 0)
	_refresh([l])
	assert(l.text == "Mercadora" and l.modulate.a < 0.3, "Perto de 6 m o nome some aos poucos (sem estalo)")
	var plain := _label_at(_WorldLabel.Kind.NAME, "Sem ícone", "", Vector3.ZERO)
	_viewer.global_position = Vector3(10, 0, 0)
	_refresh([plain])
	assert(not plain.visible, "Sem ícone, de 6 a 15 m não mostra nada")
	l.free()
	plain.free()
	# Praça cheia: 5 nomes a menos de 6 m, só os 3 mais perto por extenso
	var crowd: Array = []
	for i in 5:
		crowd.append(_label_at(_WorldLabel.Kind.NAME, "NPC %d" % i, "💬", Vector3(1.0 + i * 0.8, 2, 0)))
	_viewer.global_position = Vector3.ZERO
	_refresh(crowd)
	var full := crowd.filter(func(c): return c.visible and c.text != "💬")
	var icons := crowd.filter(func(c): return c.visible and c.text == "💬")
	assert(full.size() == _WorldLabel.MAX_NEAR_NAMES and icons.size() == 2, "Só 3 nomes por extenso (%d nomes, %d ícones)" % [full.size(), icons.size()])
	assert(full.has(crowd[0]) and full.has(crowd[2]) and not full.has(crowd[4]), "Os 3 por extenso são os mais perto")
	for c in crowd:
		c.free()
	print("  ✓ 6 m / 15 m, fade e no máximo 3 nomes")

func test_prompt_focus() -> void:
	print("\n[2/4] Só o [E] do alvo mais perto aparece...")
	var a := _label_at(_WorldLabel.Kind.PROMPT, "[E] Forjar", "", Vector3(1, 2, 0))
	var b := _label_at(_WorldLabel.Kind.PROMPT, "[E] Doar materiais", "", Vector3(2, 2, 0))
	_viewer.global_position = Vector3.ZERO
	_refresh([a, b])
	assert(a.visible and not b.visible, "Dois [E] perto: só o mais perto")
	_viewer.global_position = Vector3(2.2, 0, 0)
	_refresh([a, b])
	assert(b.visible and not a.visible, "Chegou mais perto do outro: o foco troca")
	_viewer.global_position = Vector3(8, 0, 0)
	_refresh([a, b])
	assert(not a.visible and not b.visible, "Fora do alcance: nenhum [E]")
	b.active = false
	_viewer.global_position = Vector3(2, 0, 0)
	_refresh([a, b])
	assert(a.visible and not b.visible, "Prompt desligado não rouba o foco")
	a.free()
	b.free()
	print("  ✓ foco único e alcance")

func test_sign_and_active() -> void:
	print("\n[3/4] Placa lida até o alcance; active desliga...")
	var s := _label_at(_WorldLabel.Kind.SIGN, "VILA DA ESPERANÇA", "", Vector3.ZERO)
	s.sign_range = 30.0
	_viewer.global_position = Vector3(20, 0, 0)
	_refresh([s])
	assert(s.visible and s.text == "VILA DA ESPERANÇA", "Placa a 20 m: lida inteira")
	_viewer.global_position = Vector3(40, 0, 0)
	_refresh([s])
	assert(not s.visible, "Placa além do alcance: some")
	_viewer.global_position = Vector3(5, 0, 0)
	s.active = false
	_refresh([s])
	assert(not s.visible, "active = false esconde")
	s.free()
	print("  ✓ placa e active")

func test_town_npc_uses_world_label() -> void:
	print("\n[4/4] NPC da vila usa o rótulo único...")
	var npc := _TownNPC.new()
	npc.display_name = "Mestre Construtor"
	npc.prompt = "[E] Quadro de Obras"
	npc.icon = "🔨"
	root.add_child(npc)
	var labels := npc.find_children("*", "Label3D", false, false)
	assert(labels.size() == 2, "Nome e [E] (%d rótulos)" % labels.size())
	assert(labels.all(func(l): return l is _WorldLabel), "Nenhum Label3D solto")
	npc.queue_free()
	print("  ✓ TownNPC com nome e [E] pelo WorldLabel")
