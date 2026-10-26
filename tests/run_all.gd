extends SceneTree

## Roda todos os tests/test_*.gd em processos separados e sai com código 1 se algum falhar.
# Os testes usam assert(), que no Godot só imprime o erro e segue em frente; por isso o
# runner lê a saída: falha = erro de script/asserção ou ausência da linha final de sucesso.
# (No Windows a saída capturada chega como Latin-1 e o emoji 🎉 se perde; por isso a busca
# é pelas palavras da linha final.)
# Uso: godot --path . --headless -s res://tests/run_all.gd

const FAIL_MARKERS: Array[String] = ["SCRIPT ERROR", "Assertion failed", "Parse Error"]
const SUCCESS_MARKERS: Array[String] = ["SUCESSO", "PASSARAM"]
# Um assert que falha direto no _init aborta a função antes do quit(); o teste ficaria
# rodando para sempre. --quit-after encerra o processo filho depois de N frames.
const MAX_FRAMES: int = 3000

func _initialize() -> void:
	var filter: String = ""
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not user_args.is_empty():
		filter = user_args[0].strip_edges().to_lower()
	else:
		for arg in OS.get_cmdline_args():
			if arg.begins_with("--filter="):
				filter = arg.trim_prefix("--filter=").strip_edges().to_lower()
				break

	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			if filter == "" or filter in f.to_lower():
				files.append(f)
	files.sort()

	if files.is_empty():
		print("Nenhum teste encontrado para o filtro: '%s'" % filter)
		quit(0)
		return

	if filter != "":
		print("Filtrando testes por '%s' (%d encontrados):\n" % [filter, files.size()])

	var failed: Array[String] = []
	for f in files:
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--headless", "--quit-after", str(MAX_FRAMES), "-s", "res://tests/" + f], output, true)
		var text: String = "\n".join(output)
		var problems: Array[String] = []
		for line in text.split("\n"):
			for marker in FAIL_MARKERS:
				if marker in line:
					problems.append(line.strip_edges())
		var finished: bool = SUCCESS_MARKERS.any(func(m): return m in text)
		var ok: bool = code == 0 and problems.is_empty() and finished
		print("%s  %s" % ["✅" if ok else "❌", f])
		if not ok:
			failed.append(f)
			for p in problems.slice(0, 5):
				print("      ", p)

	print("\n%d/%d arquivos de teste passaram." % [files.size() - failed.size(), files.size()])
	quit(1 if not failed.is_empty() else 0)
