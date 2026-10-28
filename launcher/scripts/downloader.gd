class_name Downloader
extends Node

## Gerencia o download de pacotes com escrita direta em disco, cálculo de velocidade e ETA.

signal download_started(total_bytes: int)
signal download_progress(downloaded_bytes: int, total_bytes: int, percent: float, speed_bps: float, eta_seconds: float)
signal download_completed(file_path: String)
signal download_failed(error_message: String)

var _http: HTTPRequest
var _target_file_path: String = ""
var _expected_total_bytes: int = 0
var _is_downloading: bool = false

var _last_downloaded_bytes: int = 0
var _speed_sample_timer: float = 0.0
var _current_speed_bps: float = 0.0

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 0 # Sem timeout estrito durante downloads longos
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func is_downloading() -> bool:
	return _is_downloading

func start_download(url: String, destination_file_path: String, expected_size_bytes: int = 0) -> void:
	if _is_downloading:
		cancel_download()
	
	_target_file_path = destination_file_path
	_expected_total_bytes = expected_size_bytes
	_last_downloaded_bytes = 0
	_speed_sample_timer = 0.0
	_current_speed_bps = 0.0
	
	# Garante que a pasta pai existe
	var parent_dir := destination_file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)
	
	# Se já existir arquivo temporário antigo, remove
	if FileAccess.file_exists(destination_file_path):
		DirAccess.remove_absolute(destination_file_path)
	
	_http.download_file = destination_file_path
	
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: CepasSelvagensLauncher/1.0",
		"Accept: application/octet-stream"
	])
	
	var err := _http.request(url, headers)
	if err != OK:
		_is_downloading = false
		download_failed.emit("Falha ao iniciar requisição de download (código: %d)" % err)
		return
	
	_is_downloading = true
	download_started.emit(_expected_total_bytes)

func cancel_download() -> void:
	if not _is_downloading:
		return
	
	_is_downloading = false
	_http.cancel_request()
	
	if FileAccess.file_exists(_target_file_path):
		DirAccess.remove_absolute(_target_file_path)
	
	download_failed.emit("Download cancelado pelo usuário.")

func _process(delta: float) -> void:
	if not _is_downloading:
		return
	
	var downloaded: int = _http.get_downloaded_bytes()
	var total: int = _http.get_body_size()
	if total <= 0 and _expected_total_bytes > 0:
		total = _expected_total_bytes
	
	# Amostragem de velocidade a cada 0.25 segundos
	_speed_sample_timer += delta
	if _speed_sample_timer >= 0.25:
		var bytes_delta: int = downloaded - _last_downloaded_bytes
		var instant_speed: float = float(bytes_delta) / _speed_sample_timer
		# Suavização por média móvel exponencial
		_current_speed_bps = lerpf(_current_speed_bps, instant_speed, 0.4)
		_last_downloaded_bytes = downloaded
		_speed_sample_timer = 0.0
	
	var percent: float = 0.0
	var eta: float = 0.0
	if total > 0:
		percent = clampf((float(downloaded) / float(total)) * 100.0, 0.0, 100.0)
		if _current_speed_bps > 1024.0:
			eta = maxf(float(total - downloaded) / _current_speed_bps, 0.0)
	
	download_progress.emit(downloaded, total, percent, _current_speed_bps, eta)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not _is_downloading:
		return
	
	_is_downloading = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		if FileAccess.file_exists(_target_file_path):
			DirAccess.remove_absolute(_target_file_path)
		download_failed.emit("Erro na transferência de dados (código: %d)" % result)
		return
	
	if response_code < 200 or response_code >= 300:
		if FileAccess.file_exists(_target_file_path):
			DirAccess.remove_absolute(_target_file_path)
		download_failed.emit("Servidor de download retornou HTTP %d." % response_code)
		return
	
	download_completed.emit(_target_file_path)

## Formata bytes de forma legível (ex: "45.2 MB")
static func format_bytes(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (float(bytes) / 1024.0)
	elif bytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (float(bytes) / (1024.0 * 1024.0))
	else:
		return "%.2f GB" % (float(bytes) / (1024.0 * 1024.0 * 1024.0))

## Formata velocidade (ex: "3.5 MB/s")
static func format_speed(speed_bps: float) -> String:
	return "%s/s" % format_bytes(int(speed_bps))

## Formata tempo restante (ex: "1m 15s" ou "45s")
static func format_time(seconds: float) -> String:
	var total_sec: int = int(round(seconds))
	if total_sec < 60:
		return "%ds" % total_sec
	var mins: int = total_sec / 60
	var rem_sec: int = total_sec % 60
	return "%dm %02ds" % [mins, rem_sec]
