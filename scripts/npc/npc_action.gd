class_name NpcAction
extends RefCounted

## Uma ação da Ficha do NPC (GDD-17 §8). Ou abre uma tela própria (`handler`, a Ficha fecha
## antes), ou desenha o conteúdo dentro da Ficha (`panel`, o retrato continua ali).

enum Kind { BUY, SELL, TRAIN, LEARN, ASK_WAY, SERVICE, TALK, OPEN }

const KIND_ICONS: Dictionary = {
	Kind.BUY: "🛒", Kind.SELL: "💰", Kind.TRAIN: "🎯", Kind.LEARN: "📖",
	Kind.ASK_WAY: "🧭", Kind.SERVICE: "🛎️", Kind.TALK: "💬", Kind.OPEN: "▶",
}

var id: StringName
var kind: Kind = Kind.OPEN
var label: String = ""
var icon: String = ""
## func(player) -> void: abre outra tela
var handler: Callable
## func(box: VBoxContainer, player, dialog) -> void: conteúdo dentro da Ficha
var panel: Callable
## func(player) -> String: "" = disponível; senão o motivo, mostrado em cinza
var check: Callable
## false = funciona mesmo com o NPC fora do horário (ex.: Conversar)
var needs_open: bool = true
## Gesto do retrato ao escolher a ação
var gesture: StringName = &"Interact"

static func make(p_id: StringName, p_kind: Kind, p_label: String, p_handler: Callable = Callable(), p_icon: String = "") -> NpcAction:
	var a := NpcAction.new()
	a.id = p_id
	a.kind = p_kind
	a.label = p_label
	a.handler = p_handler
	a.icon = p_icon if not p_icon.is_empty() else KIND_ICONS.get(p_kind, "▶")
	return a

## Ação que desenha o conteúdo dentro da Ficha
static func inline(p_id: StringName, p_kind: Kind, p_label: String, p_panel: Callable, p_icon: String = "") -> NpcAction:
	var a := make(p_id, p_kind, p_label, Callable(), p_icon)
	a.panel = p_panel
	return a

func with_check(p_check: Callable) -> NpcAction:
	check = p_check
	return self

func always_open() -> NpcAction:
	needs_open = false
	return self

func unavailable_reason(player: Node) -> String:
	if check.is_valid():
		return str(check.call(player))
	return ""
