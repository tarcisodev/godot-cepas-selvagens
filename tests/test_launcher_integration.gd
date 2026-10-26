extends SceneTree

## Teste de integração do Launcher dentro da suíte principal de testes do jogo.
## Valida execução headless do subprojeto launcher e integridade dos scripts.

func _init() -> void:
	print("\n========================================================")
	print("🚀 TESTANDO INTEGRAÇÃO DO SUBPROJETO LAUNCHER")
	print("========================================================")
	
	var godot_exe: String = OS.get_executable_path()
	var launcher_path: String = ProjectSettings.globalize_path("res://launcher")
	
	print("Executando bateria de testes do launcher: %s" % launcher_path)
	var output: Array = []
	var code: int = OS.execute(godot_exe, [
		"--path", launcher_path,
		"--headless",
		"-s", "res://tests/test_launcher.gd"
	], output, true)
	
	var text: String = "\n".join(output)
	print(text)
	
	assert(code == 0, "Processo de teste do launcher deve retornar código 0")
	assert("TODOS OS TESTES DO LAUNCHER PASSARAM COM SUCESSO!" in text, "Mensagem de sucesso do launcher confirmada")
	
	print("🎉 INTEGRAÇÃO DO LAUNCHER TESTADA COM SUCESSO!")
	print("========================================================\n")
	quit(0)
