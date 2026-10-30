class_name BraveFlight
extends RefCounted

## Voo bravio da Prova do Ninho (GDD-16 §4): por DURATION o Planador tenta derrubar o cavaleiro.
## A cada tranco (seta na tela) o jogador tem WINDOW para segurar a direção oposta (WASD).
## Errar o lado, empurrar junto com o tranco ou deixar passar enche a barra de queda; levar dano
## enche muito. Barra cheia = cai de verdade. Sem câmera lenta: tudo no tempo do mundo.
## Lógica pura, com seed (no online quem roda é o servidor; o cliente só manda o WASD).

const DURATION: float = 20.0
const WINDOW: float = 0.9
const GAP_MIN: float = 0.6
const GAP_MAX: float = 1.4
const MISS: float = 0.25
const WRONG: float = 0.3
const RIGHT: float = -0.05
const HURT: float = 0.4
## Direções do tranco no mesmo sentido do Input.get_vector (x: direita +, y: para trás +)
const JOLTS: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
const ARROWS: Dictionary = {Vector2.LEFT: "⬅", Vector2.RIGHT: "➡", Vector2.UP: "⬆", Vector2.DOWN: "⬇"}
const KEYS: Dictionary = {Vector2.LEFT: "A", Vector2.RIGHT: "D", Vector2.UP: "W", Vector2.DOWN: "S"}

var time: float = 0.0
## Barra de queda, 0 a 1
var fall: float = 0.0
## Tranco atual (zero = entre um e outro)
var jolt: Vector2 = Vector2.ZERO
var jolts: int = 0
var answered: int = 0
var _window: float = 0.0
var _gap: float = 0.0
var _rng := RandomNumberGenerator.new()

func _init(seed: int = 0) -> void:
	_rng.seed = seed
	_gap = _rng.randf_range(GAP_MIN, GAP_MAX)

## Avança o voo; devolve &"voando", &"caiu" ou &"domado"
func step(delta: float, input: Vector2) -> StringName:
	if fall >= 1.0:
		return &"caiu"
	time += delta
	if time >= DURATION:
		return &"domado"
	if jolt == Vector2.ZERO:
		_gap -= delta
		if _gap <= 0.0:
			jolt = JOLTS[_rng.randi() % JOLTS.size()]
			_window = WINDOW
			jolts += 1
		return &"voando"
	_window -= delta
	if input.length() > 0.5:
		var push := input.normalized()
		if push.dot(-jolt) > 0.7:
			fall = maxf(0.0, fall + RIGHT)
			answered += 1
			_calm()
		elif push.dot(jolt) > 0.7:
			fall += WRONG
			_calm()
	if jolt != Vector2.ZERO and _window <= 0.0:
		fall += MISS
		_calm()
	return &"caiu" if fall >= 1.0 else &"voando"

## Golpe no cavaleiro durante o voo
func hurt() -> void:
	fall += HURT

## Texto do HUD: tranco, tecla e barra
func hud_text() -> String:
	var bar := "▓".repeat(roundi(clampf(fall, 0.0, 1.0) * 10.0)) + "░".repeat(10 - roundi(clampf(fall, 0.0, 1.0) * 10.0))
	var left := maxi(0, ceili(DURATION - time))
	if jolt == Vector2.ZERO:
		return "🌀 Voo bravio · aguente %d s · Queda %s" % [left, bar]
	return "🌀 Tranco %s! segure %s [%s] · Queda %s" % [ARROWS[jolt], ARROWS[-jolt], KEYS[-jolt], bar]

func _calm() -> void:
	jolt = Vector2.ZERO
	_gap = _rng.randf_range(GAP_MIN, GAP_MAX)
