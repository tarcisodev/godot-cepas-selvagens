class_name CosmeticsCatalog
extends RefCounted

## Catálogo e construtor 3D de Cosméticos ("Ateliê Estelar").
## Permite comprar com moedas do jogo ($S), equipar no CharacterDNA e visualizar
## tanto na prévia 3D quanto no mundo aberto. Preparado para futura integração PIX.

const ITEMS: Array[Dictionary] = [
	# --- CHAPÉUS & COROAS (slot: "hat") ---
	{
		"id": "coroa_flores",
		"slot": "hat",
		"name": "Coroa de Flores Silvestres",
		"icon": "🌸",
		"price": 30,
		"desc": "Guirlanda trançada com flores rosadas, douradas e folhas vivas da várzea.",
		"color": Color(0.96, 0.52, 0.68),
	},
	{
		"id": "chapeu_cacador",
		"slot": "hat",
		"name": "Chapéu de Caçador dos Ermos",
		"icon": "🤠",
		"price": 45,
		"desc": "Chapéu de couro curtido de aba larga com pluma esmeralda.",
		"color": Color(0.45, 0.28, 0.16),
	},
	{
		"id": "chapeu_arcano",
		"slot": "hat",
		"name": "Chapéu Arcano de Lume",
		"icon": "🧙",
		"price": 65,
		"desc": "Chapéu pontiagudo de tecido noturno cravejado com cristais de quartzo-lume.",
		"color": Color(0.22, 0.34, 0.68),
	},
	{
		"id": "diadema_solar",
		"slot": "hat",
		"name": "Diadema Solar Dourado",
		"icon": "👑",
		"price": 80,
		"desc": "Tiara real forjada em ouro antigo com gema rubi central.",
		"color": Color(0.96, 0.78, 0.24),
	},
	{
		"id": "halo_anelado",
		"slot": "hat",
		"name": "Halo do Planeta Anelado",
		"icon": "🪐",
		"price": 110,
		"desc": "Miniatura flutuante de um astro com anéis luminosos sobre a cabeça.",
		"color": Color(0.45, 0.85, 0.98),
	},

	# --- CAPAS & MANTOS (slot: "cape") ---
	{
		"id": "manto_andarilho",
		"slot": "cape",
		"name": "Manto do Andarilho Verde",
		"icon": "🌿",
		"price": 40,
		"desc": "Capa leve de linho musgo para caminhadas na floresta e chuva.",
		"color": Color(0.22, 0.44, 0.26),
	},
	{
		"id": "capa_fogueira",
		"slot": "cape",
		"name": "Capa Rubra da Fogueira",
		"icon": "🔥",
		"price": 60,
		"desc": "Manto carmesim com borda dourada que aquece nas noites frias.",
		"color": Color(0.76, 0.18, 0.18),
	},
	{
		"id": "manto_estrelado",
		"slot": "cape",
		"name": "Manto Noite Estrelada",
		"icon": "🌌",
		"price": 90,
		"desc": "Tecido azul-abissal com brilho sutil que lembra a cúpula celeste.",
		"color": Color(0.14, 0.20, 0.48),
	},
	{
		"id": "manto_rosa_real",
		"slot": "cape",
		"name": "Manto Rosa da Alvorada",
		"icon": "🌸",
		"price": 75,
		"desc": "Manto elegante em tom rosa-aurora e fios prateados.",
		"color": Color(0.84, 0.38, 0.56),
	},

	# --- AURAS & EFEITOS (slot: "aura") ---
	{
		"id": "aura_vagalumes",
		"slot": "aura",
		"name": "Cortejo de Vagalumes",
		"icon": "🧚",
		"price": 55,
		"desc": "Pequenos pontos de luz dourada e esverdeada que orbitam você.",
		"color": Color(0.75, 0.98, 0.35),
	},
	{
		"id": "aura_lume",
		"slot": "aura",
		"name": "Essência de Pinheira-Lume",
		"icon": "💠",
		"price": 85,
		"desc": "Orbes bioluminescentes ciano-turquesa flutuando ao redor do corpo.",
		"color": Color(0.25, 0.92, 0.88),
	},
	{
		"id": "aura_cosmica",
		"slot": "aura",
		"name": "Órbita Cósmica Anelada",
		"icon": "🪐",
		"price": 120,
		"desc": "Anel de poeira estelar violeta e dourada girando suavemente.",
		"color": Color(0.78, 0.48, 0.98),
	},

	# --- TRAJES RÁPIDOS (slot: "outfit") ---
	{
		"id": "traje_rosa_silvestre",
		"slot": "outfit",
		"name": "Traje Rosa Silvestre",
		"icon": "🌹",
		"price": 35,
		"desc": "Túnica rosa-silvestre com calça creme e botas de couro claro.",
		"shirt": Color("#c85a7c"),
		"pants": Color("#d8cbb8"),
		"boots": Color("#5e3d24"),
	},
	{
		"id": "traje_safira_astral",
		"slot": "outfit",
		"name": "Traje Safira Astral",
		"icon": "💎",
		"price": 40,
		"desc": "Túnica azul-safira com detalhes escuros e botas de explorador.",
		"shirt": Color("#2e5b88"),
		"pants": Color("#232936"),
		"boots": Color("#3a2a1e"),
	},
	{
		"id": "traje_sol_dourado",
		"slot": "outfit",
		"name": "Traje Sol Dourado",
		"icon": "☀️",
		"price": 50,
		"desc": "Veste dourada radiante da Vila da Esperança.",
		"shirt": Color("#d49b35"),
		"pants": Color("#4a3828"),
		"boots": Color("#4a3020"),
	},
]

## Pacotes de Apoio PIX (Prévia para monetização futura)
const PIX_PACKS: Array[Dictionary] = [
	{
		"id": "pack_casal",
		"name": "💑 Pacote Casal Explorador (Apoiador)",
		"price_brl": "R$ 9,90 (Em breve via PIX)",
		"desc": "Desbloqueia Coroa de Flores, Halo Anelado, Manto Estrelado + 500 $S para o casal jogar junto!",
		"bonus_gold": 250,
	},
	{
		"id": "pack_cosmos",
		"name": "🪐 Pacote Guardião do Cosmos",
		"price_brl": "R$ 14,90 (Em breve via PIX)",
		"desc": "Conjunto completo do Planeta Anelado: Halo, Órbita Cósmica e Manto Noite Estrelada.",
		"bonus_gold": 300,
	},
]

static func get_item(id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return item
	return {}

static func items_by_slot(slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in ITEMS:
		if item.slot == slot:
			out.append(item)
	return out

## Anexa os modelos 3D procedurais dos cosméticos equipados no CharacterVisual
static func attach_to_visual(visual: Node3D, skeleton: Skeleton3D, dna: CharacterDNA) -> void:
	if visual == null or skeleton == null or dna == null:
		return
	# Remove cosméticos anteriores
	for child in skeleton.get_children():
		if child.name.begins_with("Cosmetic_"):
			child.free()
	for child in visual.get_children():
		if child.name.begins_with("Cosmetic_"):
			child.free()

	if not dna.cosmetic_hat.is_empty():
		var head_idx := skeleton.find_bone("Head")
		if head_idx >= 0:
			var sock := BoneAttachment3D.new()
			sock.name = "Cosmetic_HatSocket"
			sock.bone_name = "Head"
			skeleton.add_child(sock)
			var hat_node := _build_hat_mesh(dna.cosmetic_hat, dna.head_size)
			if hat_node:
				sock.add_child(hat_node)

	if not dna.cosmetic_cape.is_empty():
		var spine_idx := skeleton.find_bone("spine_03")
		if spine_idx >= 0:
			var sock := BoneAttachment3D.new()
			sock.name = "Cosmetic_CapeSocket"
			sock.bone_name = "spine_03"
			skeleton.add_child(sock)
			var cape_node := _build_cape_mesh(dna.cosmetic_cape)
			if cape_node:
				sock.add_child(cape_node)

	if not dna.cosmetic_aura.is_empty():
		var aura_node := _build_aura_node(dna.cosmetic_aura)
		if aura_node:
			aura_node.name = "Cosmetic_Aura"
			visual.add_child(aura_node)

static func _mat(color: Color, emission_strength: float = 0.0, roughness: float = 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission_strength > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission_strength
	return m

static func _build_hat_mesh(hat_id: String, head_size: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.0, 0.17 * head_size, 0.01)
	root.scale = Vector3.ONE * head_size

	match hat_id:
		"coroa_flores":
			var ring_mat := _mat(Color(0.25, 0.52, 0.22), 0.0, 0.8)
			var torus := TorusMesh.new()
			torus.inner_radius = 0.095
			torus.outer_radius = 0.118
			var base := MeshInstance3D.new()
			base.mesh = torus
			base.material_override = ring_mat
			base.rotation_degrees.x = -8.0
			root.add_child(base)
			var flower_colors: Array[Color] = [
				Color(0.98, 0.48, 0.65),
				Color(1.0, 0.85, 0.32),
				Color(0.95, 0.92, 0.98),
				Color(0.88, 0.42, 0.85),
			]
			for i in 8:
				var ang := float(i) * TAU / 8.0
				var fl := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 0.022
				sp.height = 0.032
				fl.mesh = sp
				fl.material_override = _mat(flower_colors[i % flower_colors.size()], 0.25)
				fl.position = Vector3(cos(ang) * 0.106, 0.008, sin(ang) * 0.106)
				root.add_child(fl)
		"chapeu_cacador":
			var leather := _mat(Color(0.38, 0.23, 0.13), 0.0, 0.75)
			var brim := MeshInstance3D.new()
			var brim_cyl := CylinderMesh.new()
			brim_cyl.top_radius = 0.19
			brim_cyl.bottom_radius = 0.20
			brim_cyl.height = 0.014
			brim.mesh = brim_cyl
			brim.material_override = leather
			root.add_child(brim)
			var crown := MeshInstance3D.new()
			var crown_cyl := CylinderMesh.new()
			crown_cyl.top_radius = 0.085
			crown_cyl.bottom_radius = 0.108
			crown_cyl.height = 0.11
			crown.mesh = crown_cyl
			crown.position.y = 0.055
			crown.material_override = leather
			root.add_child(crown)
			# Pluma esmeralda
			var plume := MeshInstance3D.new()
			var p_mesh := BoxMesh.new()
			p_mesh.size = Vector3(0.015, 0.11, 0.04)
			plume.mesh = p_mesh
			plume.position = Vector3(0.095, 0.08, -0.01)
			plume.rotation_degrees = Vector3(-15, 0, -18)
			plume.material_override = _mat(Color(0.22, 0.78, 0.45), 0.3)
			root.add_child(plume)
		"chapeu_arcano":
			var cloth := _mat(Color(0.16, 0.24, 0.52), 0.15, 0.8)
			var brim := MeshInstance3D.new()
			var brim_cyl := CylinderMesh.new()
			brim_cyl.top_radius = 0.22
			brim_cyl.bottom_radius = 0.23
			brim_cyl.height = 0.012
			brim.mesh = brim_cyl
			brim.material_override = cloth
			root.add_child(brim)
			var cone := MeshInstance3D.new()
			var cone_cyl := CylinderMesh.new()
			cone_cyl.top_radius = 0.01
			cone_cyl.bottom_radius = 0.11
			cone_cyl.height = 0.24
			cone.mesh = cone_cyl
			cone.position.y = 0.12
			cone.rotation_degrees.x = -10.0
			cone.material_override = cloth
			root.add_child(cone)
			var gem := MeshInstance3D.new()
			var gem_sp := SphereMesh.new()
			gem_sp.radius = 0.022
			gem_sp.height = 0.044
			gem.mesh = gem_sp
			gem.position = Vector3(0.0, 0.04, 0.105)
			gem.material_override = _mat(Color(0.35, 0.95, 0.98), 1.6)
			root.add_child(gem)
		"diadema_solar":
			var gold := _mat(Color(0.98, 0.78, 0.22), 0.45, 0.3)
			var torus := TorusMesh.new()
			torus.inner_radius = 0.094
			torus.outer_radius = 0.108
			var band := MeshInstance3D.new()
			band.mesh = torus
			band.material_override = gold
			root.add_child(band)
			for i in 5:
				var ang := deg_to_rad(-50.0 + float(i) * 25.0)
				var spike := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.003
				cyl.bottom_radius = 0.014
				cyl.height = 0.055 if i == 2 else 0.036
				spike.mesh = cyl
				spike.position = Vector3(sin(ang) * 0.102, 0.028, cos(ang) * 0.102)
				spike.material_override = _mat(Color(0.95, 0.22, 0.28), 1.2) if i == 2 else gold
				root.add_child(spike)
		"halo_anelado":
			root.position.y += 0.14
			var planet := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.038
			sp.height = 0.076
			planet.mesh = sp
			planet.material_override = _mat(Color(0.92, 0.68, 0.38), 0.9)
			root.add_child(planet)
			var ring := MeshInstance3D.new()
			var tr := TorusMesh.new()
			tr.inner_radius = 0.062
			tr.outer_radius = 0.095
			ring.mesh = tr
			ring.rotation_degrees = Vector3(24.0, 0.0, -18.0)
			ring.scale.y = 0.22
			ring.material_override = _mat(Color(0.45, 0.88, 0.98), 1.4)
			root.add_child(ring)
	return root

static func _build_cape_mesh(cape_id: String) -> Node3D:
	var item := get_item(cape_id)
	var col: Color = item.get("color", Color(0.25, 0.45, 0.3))
	var glow := 0.35 if cape_id == "manto_estrelado" else 0.05

	var root := Node3D.new()
	# No espaço do osso spine_03, costas ficam em -Z
	var cape := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.34, 0.68, 0.018)
	cape.mesh = box
	cape.position = Vector3(0.0, -0.26, -0.13)
	cape.rotation_degrees.x = 10.0
	cape.material_override = _mat(col, glow, 0.85)
	root.add_child(cape)

	# Gola nos ombros
	var collar := MeshInstance3D.new()
	var tr := TorusMesh.new()
	tr.inner_radius = 0.11
	tr.outer_radius = 0.145
	collar.mesh = tr
	collar.position = Vector3(0.0, 0.06, -0.02)
	collar.scale = Vector3(1.15, 0.5, 0.95)
	collar.material_override = _mat(col.lightened(0.15), glow * 1.2, 0.8)
	root.add_child(collar)
	return root

static func _build_aura_node(aura_id: String) -> Node3D:
	var item := get_item(aura_id)
	var col: Color = item.get("color", Color(0.4, 0.95, 0.8))

	var root := Node3D.new()
	root.position = Vector3(0.0, 0.95, 0.0)
	var count := 6
	for i in count:
		var ang := float(i) * TAU / float(count)
		var orb := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.028
		sp.height = 0.056
		orb.mesh = sp
		orb.position = Vector3(cos(ang) * 0.48, sin(ang * 2.0) * 0.22, sin(ang) * 0.48)
		orb.material_override = _mat(col, 2.2, 0.2)
		root.add_child(orb)

	if aura_id == "aura_cosmica":
		var ring := MeshInstance3D.new()
		var tr := TorusMesh.new()
		tr.inner_radius = 0.50
		tr.outer_radius = 0.53
		ring.mesh = tr
		ring.rotation_degrees = Vector3(18.0, 0.0, -14.0)
		ring.scale.y = 0.15
		ring.material_override = _mat(col.lightened(0.2), 1.8)
		root.add_child(ring)
	return root
