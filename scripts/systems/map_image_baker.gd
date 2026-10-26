class_name MapImageBaker
extends RefCounted

## Gerador de Textura Cartográfica em Pergaminho (GDD-11 §3 e B21).
## Converte o relevo real do terreno (LandscapeGenerator) e a hidrografia (RiverSystem)
## em uma imagem de alta resolução (512x512) estilo carta náutica/topográfica envelhecida.
## Gera apenas UMA vez ao carregar o mundo e armazena em cache para performance máxima.

const MAP_RESOLUTION: int = 512
const CONTOUR_INTERVAL: float = 4.0 ## Curvas de nível a cada 4 metros (GDD-11 §3)
const CONTOUR_LINE_WIDTH: float = 0.35

# Paleta de cores estilo pergaminho e tinta histórica
const COLOR_PARCHMENT_LIGHT: Color = Color(0.91, 0.85, 0.72)
const COLOR_PARCHMENT_DARK: Color = Color(0.83, 0.76, 0.62)
const COLOR_CONTOUR_LINE: Color = Color(0.58, 0.48, 0.36, 0.65)
const COLOR_WATER_RIVER: Color = Color(0.26, 0.48, 0.64)
const COLOR_WATER_DEEP: Color = Color(0.18, 0.36, 0.52)
const COLOR_WATER_EDGE: Color = Color(0.35, 0.56, 0.72)
const COLOR_BORDER_INK: Color = Color(0.32, 0.25, 0.18)

static var _cached_map_texture: ImageTexture = null

## Retorna a textura de mapa gerada em cache ou cria uma nova
static func get_or_bake_map(landscape: Node = null) -> ImageTexture:
	if _cached_map_texture != null:
		return _cached_map_texture
	_cached_map_texture = bake_map_texture(landscape)
	return _cached_map_texture

## Força nova geração da textura
static func bake_map_texture(landscape: Node = null) -> ImageTexture:
	var img := Image.create(MAP_RESOLUTION, MAP_RESOLUTION, false, Image.FORMAT_RGBA8)
	var half_size: float = WorldBounds.HALF
	var step_world: float = (half_size * 2.0) / float(MAP_RESOLUTION)

	# Vetor de luz direcional para o hillshading (Noroeste a 315°, elevação de 45°)
	var light_dir := Vector3(-0.6, 0.7, -0.4).normalized()

	for py in MAP_RESOLUTION:
		var wz: float = -half_size + float(py) * step_world
		for px in MAP_RESOLUTION:
			var wx: float = -half_size + float(px) * step_world

			# Consulta altura
			var h: float = 0.0
			var h_east: float = 0.0
			var h_south: float = 0.0

			if landscape and landscape.has_method("get_height_at"):
				h = landscape.get_height_at(wx, wz)
				h_east = landscape.get_height_at(wx + 0.8, wz)
				h_south = landscape.get_height_at(wx, wz + 0.8)
			else:
				h = _mock_height(wx, wz)
				h_east = _mock_height(wx + 0.8, wz)
				h_south = _mock_height(wx, wz + 0.8)

			# 1. Checagem de Rio e Água (RiverSystem)
			var river_center: float = RiverSystem.get_river_center_x(wz)
			var dist_river: float = abs(wx - river_center)
			var water_half_w: float = RiverSystem.get_water_half_width(wz)

			var pixel_color: Color

			if dist_river <= water_half_w:
				# Dentro do leito do rio ou lagoa da cachoeira
				var is_deep: bool = abs(wz - RiverSystem.WATERFALL_Z) < 8.0 or dist_river < water_half_w * 0.4
				var base_water := COLOR_WATER_DEEP if is_deep else COLOR_WATER_RIVER
				# Margem da água com linha de rebordo sutil
				if dist_river >= water_half_w * 0.85:
					pixel_color = COLOR_WATER_EDGE
				else:
					pixel_color = base_water
			else:
				# 2. Terreno em Pergaminho com Hillshading
				# Gradiente de altura da terra
				var height_factor: float = clampf((h + 5.0) / 35.0, 0.0, 1.0)
				var base_parchment := COLOR_PARCHMENT_DARK.lerp(COLOR_PARCHMENT_LIGHT, height_factor)

				# Cálculo da normal da superfície para relevo sombreado
				var slope_x: float = (h_east - h) / 0.8
				var slope_z: float = (h_south - h) / 0.8
				var normal := Vector3(-slope_x, 1.0, -slope_z).normalized()
				var shade: float = clampf(normal.dot(light_dir), 0.55, 1.25)

				pixel_color = base_parchment * shade
				pixel_color.a = 1.0

				# 3. Curvas de Nível (Contour lines a cada 4 metros)
				var mod_h: float = fposmod(h, CONTOUR_INTERVAL)
				if mod_h < CONTOUR_LINE_WIDTH or (CONTOUR_INTERVAL - mod_h) < CONTOUR_LINE_WIDTH:
					pixel_color = pixel_color.lerp(COLOR_CONTOUR_LINE, 0.60)

			# 4. Moldura externa clássica de pergaminho
			var border_dist: int = mini(mini(px, MAP_RESOLUTION - 1 - px), mini(py, MAP_RESOLUTION - 1 - py))
			if border_dist < 4:
				pixel_color = COLOR_BORDER_INK
			elif border_dist == 8 or border_dist == 9:
				pixel_color = COLOR_BORDER_INK.lerp(pixel_color, 0.3)

			img.set_pixel(px, py, pixel_color)

	# Desenha Rosa dos Ventos clássica no canto superior direito
	_draw_compass_rose(img, MAP_RESOLUTION - 46, 46, 26)

	return ImageTexture.create_from_image(img)

## Desenha os 4 raios da rosa dos ventos na textura
static func _draw_compass_rose(img: Image, cx: int, cy: int, radius: int) -> void:
	# Círculo externo
	for a in range(0, 360, 5):
		var rad := deg_to_rad(float(a))
		var px := int(round(float(cx) + cos(rad) * float(radius)))
		var py := int(round(float(cy) + sin(rad) * float(radius)))
		if px >= 0 and px < MAP_RESOLUTION and py >= 0 and py < MAP_RESOLUTION:
			img.set_pixel(px, py, COLOR_BORDER_INK)

	# Raios principais (Norte, Sul, Leste, Oeste)
	for i in range(1, radius - 2):
		_safe_pixel(img, cx, cy - i, Color(0.78, 0.15, 0.15)) # Norte Vermelho
		_safe_pixel(img, cx, cy + i, COLOR_BORDER_INK)         # Sul
		_safe_pixel(img, cx + i, cy, COLOR_BORDER_INK)         # Leste
		_safe_pixel(img, cx - i, cy, COLOR_BORDER_INK)         # Oeste

## Aplica pixel seguro dentro dos limites
static func _safe_pixel(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < MAP_RESOLUTION and y >= 0 and y < MAP_RESOLUTION:
		img.set_pixel(x, y, color)

## Função determinística de altura para testes e fallback
static func _mock_height(wx: float, wz: float) -> float:
	var dist_peak := Vector2(wx - (-28.0), wz - (-52.0)).length()
	var h := 0.0
	if dist_peak < 38.0:
		h += pow(1.0 - (dist_peak / 38.0), 1.8) * 17.5
	if wz < RiverSystem.WATERFALL_Z:
		h += clampf((RiverSystem.WATERFALL_Z - wz) / 8.0, 0.0, 1.0) * 8.2
	h += sin(wx * 0.05) * cos(wz * 0.05) * 3.5
	return h
