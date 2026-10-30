class_name NpcProfile
extends RefCounted

## Quem o NPC é na Ficha do [E] (GDD-17 §8–9): nome, papel, bairro, horário, falas e ações.
## O horário e a saudação saem só da hora do relógio único (ADR-0006): no online todo
## jogador vê a mesma coisa, sem estado por cliente.

const _NpcAction = preload("res://scripts/npc/npc_action.gd")

var id: StringName
var display_name: String = ""
## Papel em cima do nome: "Mestra de Lâminas", "Boticária"…
var title: String = ""
var icon: String = "💬"
var district: String = ""
## Cor do fundo do retrato e da borda da Ficha
var color: Color = Color(0.85, 0.72, 0.35)
## Horário de trabalho; open_hour < 0 = atende 24 h. close < open atravessa a meia-noite.
var open_hour: float = -1.0
var close_hour: float = -1.0
## Onde o NPC está quando fecha ("ela está na Estalagem"); vazio = só "Fechado"
var off_hours_note: String = ""
## Saudações por período: "manha" (6–12), "tarde" (12–18), "noite" (18–6); "sempre" vale em qualquer hora
var greetings: Dictionary = {}
## Assuntos do Conversar: [{"q": "pergunta", "a": "resposta"}]
var topics: Array[Dictionary] = []
var talk_anim: StringName = &"Idle_Talking"
var actions: Array[_NpcAction] = []

static func make(p_id: StringName, p_name: String, p_title: String, p_icon: String, p_district: String = "") -> NpcProfile:
	var p := NpcProfile.new()
	p.id = p_id
	p.display_name = p_name
	p.title = p_title
	p.icon = p_icon
	p.district = p_district
	return p

func hours(p_open: float, p_close: float, note: String = "") -> NpcProfile:
	open_hour = p_open
	close_hour = p_close
	off_hours_note = note
	return self

func add(action: _NpcAction) -> NpcProfile:
	actions.append(action)
	return self

func greet(period: String, line: String) -> NpcProfile:
	if not greetings.has(period):
		greetings[period] = []
	greetings[period].append(line)
	return self

func topic(question: String, answer: String) -> NpcProfile:
	topics.append({"q": question, "a": answer})
	return self

func is_always_open() -> bool:
	return open_hour < 0.0

func is_open_at(hour: float) -> bool:
	if is_always_open():
		return true
	var h := fposmod(hour, 24.0)
	if close_hour > open_hour:
		return h >= open_hour and h < close_hour
	return h >= open_hour or h < close_hour

func hours_text() -> String:
	if is_always_open():
		return "Atende a qualquer hora"
	return "Atende das %dh às %dh" % [int(open_hour), int(close_hour)]

## Motivo de estar fechado, para a ação cinza; "" se está aberto
func closed_reason(hour: float) -> String:
	if is_open_at(hour):
		return ""
	var text := "Fechado, abre às %dh" % int(open_hour)
	return text + (" — " + off_hours_note if not off_hours_note.is_empty() else "")

static func period_of(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	if h >= 6.0 and h < 12.0:
		return "manha"
	if h >= 12.0 and h < 18.0:
		return "tarde"
	return "noite"

## Saudação da hora: o período tem prioridade sobre "sempre"; `seed` escolhe entre as opções
func greeting_at(hour: float, seed: int = 0) -> String:
	var options: Array = greetings.get(period_of(hour), [])
	if options.is_empty():
		options = greetings.get("sempre", [])
	if options.is_empty():
		return ""
	return str(options[absi(seed) % options.size()])

## "" = pode usar agora; senão o motivo (fechado, requisito)
func action_reason(action: _NpcAction, player: Node, hour: float) -> String:
	if action.needs_open:
		var closed := closed_reason(hour)
		if not closed.is_empty():
			return closed
	return action.unavailable_reason(player)

## Ações na ordem da Ficha, com Conversar no fim quando há assuntos
func all_actions() -> Array[_NpcAction]:
	var list: Array[_NpcAction] = actions.duplicate()
	if not topics.is_empty() and not list.any(func(a: _NpcAction): return a.kind == _NpcAction.Kind.TALK):
		list.append(_NpcAction.inline(&"conversar", _NpcAction.Kind.TALK, "Conversar", Callable()).always_open())
	return list
