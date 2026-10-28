extends SceneTree

## Tela 18+ (B34 · T01): padrão falso, aceitar grava e persiste, "Sair" não grava,
## e o splash só manda para a tela 18+ enquanto faltar a confirmação.
# O teste guarda e restaura o user://settings.cfg real para não mexer nas opções do jogador.

const _AgeGate = preload("res://scripts/ui/age_gate.gd")
const GameSettingsScript = preload("res://scripts/game_settings.gd")

var _started: bool = false
var _backup: PackedByteArray = PackedByteArray()
var _had_file: bool = false

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	print("\n========================================================")
	print("🔞 VALIDANDO TELA 18+ (B34 · T01)")
	print("========================================================")
	_backup_settings()
	_test_default_is_false()
	_test_accept_persists()
	_test_exit_does_not_confirm()
	_restore_settings()
	print("\n🎉 TELA 18+ VALIDADA COM SUCESSO!")
	print("========================================================\n")
	quit(0)

func _backup_settings() -> void:
	_had_file = FileAccess.file_exists(GameSettingsScript.SAVE_PATH)
	if _had_file:
		_backup = FileAccess.get_file_as_bytes(GameSettingsScript.SAVE_PATH)

func _restore_settings() -> void:
	if _had_file:
		var f := FileAccess.open(GameSettingsScript.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(_backup)
		f.close()
	elif FileAccess.file_exists(GameSettingsScript.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettingsScript.SAVE_PATH))
	root.get_node("GameSettings")._load()

func _test_default_is_false() -> void:
	print("\n[1/3] Padrão da flag legal/age_confirmed...")
	assert(GameSettingsScript.DEFAULTS.has("legal"), "GameSettings tem a seção legal")
	assert(GameSettingsScript.DEFAULTS["legal"]["age_confirmed"] == false, "Idade começa sem confirmação")
	var gs: Node = root.get_node("GameSettings")
	gs.set_value("legal", "age_confirmed", false)
	assert(_AgeGate.is_needed(gs), "Sem confirmação a tela 18+ é necessária")
	assert(_AgeGate.scene_after_splash(gs) == _AgeGate.SCENE_PATH, "Splash vai para a tela 18+")
	assert(ResourceLoader.exists(_AgeGate.SCENE_PATH), "Cena da tela 18+ existe")
	print("  ✓ Começa falsa e o splash leva à tela 18+")

func _test_accept_persists() -> void:
	print("\n[2/3] Aceitar grava e persiste...")
	var gs: Node = root.get_node("GameSettings")
	gs.set_value("legal", "age_confirmed", false)
	var gate: Control = _AgeGate.new()
	gate.auto_navigate = false
	root.add_child(gate)
	assert(gate.accept_button != null and gate.exit_button != null, "Botões montados")
	assert(gate.accept_button.text == _AgeGate.ACCEPT_TEXT, "Texto do botão de aceitar")
	var got := [false]
	gate.accepted.connect(func(): got[0] = true)
	gate.accept_button.pressed.emit()
	assert(got[0], "Sinal accepted emitido")
	assert(bool(gs.get_value("legal", "age_confirmed")), "Flag ligada na memória")
	var cfg := ConfigFile.new()
	assert(cfg.load(GameSettingsScript.SAVE_PATH) == OK, "settings.cfg gravado")
	assert(bool(cfg.get_value("legal", "age_confirmed", false)), "Flag persistida no disco")
	assert(not _AgeGate.is_needed(gs), "Depois de aceitar a tela não aparece de novo")
	assert(_AgeGate.scene_after_splash(gs) == _AgeGate.MAIN_MENU_SCENE, "Splash vai direto ao menu")
	gate.free()
	print("  ✓ Aceitar grava legal/age_confirmed e pula a tela nas próximas vezes")

func _test_exit_does_not_confirm() -> void:
	print("\n[3/3] Sair não confirma...")
	var gs: Node = root.get_node("GameSettings")
	gs.set_value("legal", "age_confirmed", false)
	var gate: Control = _AgeGate.new()
	gate.auto_navigate = false
	root.add_child(gate)
	var got := [false]
	gate.exited.connect(func(): got[0] = true)
	gate.exit_button.pressed.emit()
	assert(got[0], "Sinal exited emitido")
	assert(not bool(gs.get_value("legal", "age_confirmed")), "Sair não liga a flag")
	gate.free()
	print("  ✓ Sair fecha sem gravar confirmação")
