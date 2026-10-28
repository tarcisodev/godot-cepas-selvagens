class_name PatchDownloader
extends Node

## Gerencia o download de pacotes (.pck) com gravação direta em disco,
## cálculo de velocidade e tempo estimado (ETA).

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
	_http.timeout = 0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func _process(delta: float) -> void:
	if not _is_downloading or _http == null:
		return
	
	var downloaded := _http.get_downloaded_bytes()
	var body_size := _http.get_body_size()
	var total := _expected_total_bytes if _expected_total_bytes > 0 else body_size
	
	_speed_sample_timer += delta
	if _speed_sample_timer >= 0.5:
		var bytes_diff := downloaded - _last_downloaded_bytes
		_current_speed_bps = float(bytes_diff) / _speed_sample_timer
		_last_downloaded_bytes = downloaded
		_speed_sample_timer = 0.0
	
	var percent := 0.0
	var eta := 0.0
	if total > 0:
		percent = clampf(float(downloaded) / float(total) * 100.0, 0.0, 100.0)
		if _current_speed_bps > 0.0:
			var remaining_bytes := total - downloaded
			eta = maxf(0.0, float(remaining_bytes) / _current_speed_bps)
	
	download_progress.emit(downloaded, total, percent, _current_speed_bps, eta)

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
	
	var parent_dir := destination_file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)
	
	if FileAccess.file_exists(destination_file_path):
		DirAccess.remove_absolute(destination_file_path)
	
	_http.download_file = destination_file_path
	
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: CepaSelvagemGame/1.0",
		"Accept: application/octet-stream"
	])
	
	var err := _http.request(url, headers)
	if err != OK:
		_is_downloading = false
		download_failed.emit("Falha ao iniciar conexão de download (código: %d)" % err)
		return
	
	_is_downloading = true
	download_started.emit(_expected_total_bytes)

func cancel_download() -> void:
	if not _is_downloading:
		return
	
	_is_downloading = false
	_http.cancel_request()
	
	if not _target_file_path.is_empty() and FileAccess.file_exists(_target_file_path):
		DirAccess.remove_absolute(_target_file_path)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not _is_downloading:
		return
	
	_is_downloading = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		if FileAccess.file_exists(_target_file_path):
			DirAccess.remove_absolute(_target_file_path)
		download_failed.emit("Erro de conexão durante o download (código: %d)" % result)
		return
	
	if response_code < 200 or response_code >= 300:
		if FileAccess.file_exists(_target_file_path):
			DirAccess.remove_absolute(_target_file_path)
		download_failed.emit("Servidor de download retornou código HTTP %d" % response_code)
		return
	
	if not FileAccess.file_exists(_target_file_path):
		download_failed.emit("Arquivo baixado não foi encontrado no disco.")
		return
	
	var final_size := FileAccess.get_file_as_bytes(_target_file_path).size()
	if _expected_total_bytes > 0 and final_size != _expected_total_bytes:
		push_warning("[PatchDownloader] Tamanho do arquivo diverge do esperado: %d vs %d" % [final_size, _expected_total_bytes])
	
	download_completed.emit(_target_file_path)
