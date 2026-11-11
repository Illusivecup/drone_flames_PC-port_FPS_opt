class_name GitHubUpdater
extends Node
## Модуль автоматических обновлений DroneFlames Reborn через GitHub Releases

signal update_available(new_version: String, changelog: String, download_url: String, asset_name: String)
signal no_update_found()
signal check_failed(reason: String)
signal download_progress(received_bytes: int, total_bytes: int, percent: float)
signal download_completed(local_file_path: String)
signal download_failed(reason: String)

@export var enabled: bool = true ## Активировать проверку при старте
@export var repo_owner: String = "Illusivecup"
@export var repo_name: String = "drone_flames_PC-port_FPS_opt"
@export var current_version: String = "1.0.0"

var latest_tag: String = ""
var latest_changelog: String = ""
var latest_url: String = ""
var latest_asset_name: String = ""
var is_update_ready: bool = false

func has_update() -> bool:
        return is_update_ready

var _http_check: HTTPRequest
var _http_download: HTTPRequest
var _is_downloading: bool = false
var _download_path: String = ""

static func clean_version_string(v: String) -> String:
        var s: String = v.strip_edges()
        if s.begins_with("v") or s.begins_with("V"):
                s = s.substr(1).strip_edges()
        var sp: int = s.find(" ")
        if sp != -1:
                s = s.substr(0, sp)
        var paren: int = s.find("(")
        if paren != -1:
                s = s.substr(0, paren)
        var dash: int = s.find("-")
        if dash != -1:
                s = s.substr(0, dash)
        return s.strip_edges()

static func get_installed_version() -> String:
        if ResourceLoader.exists("res://version_info.json"):
                var f := FileAccess.open("res://version_info.json", FileAccess.READ)
                if f != null:
                        var txt := f.get_as_text()
                        var json = JSON.parse_string(txt)
                        if json is Dictionary and json.has("version"):
                                var v: String = clean_version_string(String(json["version"]))
                                if v != "":
                                        return v
        if ResourceLoader.exists("res://ui/menus.gd"):
                var m_cls = load("res://ui/menus.gd")
                if m_cls != null and "VERSION" in m_cls:
                        var v_str: String = clean_version_string(String(m_cls.VERSION))
                        if v_str != "":
                                return v_str
        return "0.33.5.4"

func _ready() -> void:
        current_version = get_installed_version()
        _http_check = HTTPRequest.new()
        _http_check.name = "GitHubUpdateCheckRequest"
        add_child(_http_check)
        _http_check.request_completed.connect(_on_check_request_completed)

        _http_download = HTTPRequest.new()
        _http_download.name = "GitHubUpdateDownloadRequest"
        add_child(_http_download)
        _http_download.request_completed.connect(_on_download_request_completed)

        if enabled:
                check_for_updates()

func _process(_delta: float) -> void:
        if _is_downloading and _http_download != null:
                var body_size: int = _http_download.get_body_size()
                var downloaded: int = _http_download.get_downloaded_bytes()
                if body_size > 0:
                        var pct: float = clampf(float(downloaded) / float(body_size) * 100.0, 0.0, 100.0)
                        download_progress.emit(downloaded, body_size, pct)

## Запуск проверки обновлений через GitHub REST API
func check_for_updates() -> void:
        current_version = get_installed_version()
        is_update_ready = false
        if _http_check.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
                _http_check.cancel_request()

        var url: String = "https://api.github.com/repos/%s/%s/releases/latest" % [repo_owner, repo_name]
        print("[Updater] Checking for updates at: ", url, " (current: v", current_version, ")")
        var headers: PackedStringArray = PackedStringArray([
                "User-Agent: DroneFlames-Reborn",
                "Accept: application/vnd.github+json",
                "Accept: application/vnd.github.v3+json"
        ])
        
        var err: Error = _http_check.request(url, headers)
        if err != OK:
                print("[Updater] Request failed: ", err)
                check_failed.emit("Не удалось отправить запрос к GitHub API: %d" % err)

func _on_check_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
        print("[Updater] GitHub response: code=", response_code, " result=", result)
        if result != HTTPRequest.RESULT_SUCCESS:
                check_failed.emit("Сетевая ошибка при проверке обновлений: %d" % result)
                return

        if response_code != 200:
                print("[Updater] GitHub API non-200 status: ", response_code)
                check_failed.emit("GitHub API вернул статус %d" % response_code)
                return

        var json_str: String = body.get_string_from_utf8()
        var test_json: JSON = JSON.new()
        var parse_err: Error = test_json.parse(json_str)
        if parse_err != OK:
                check_failed.emit("Ошибка парсинга ответа GitHub: %s" % test_json.get_error_message())
                return

        var data: Dictionary = test_json.data if test_json.data is Dictionary else {}
        var tag: String = clean_version_string(String(data.get("tag_name", "")))
        var changelog: String = String(data.get("body", ""))
        var assets: Array = data.get("assets", [])

        # Если тег "latest", извлекаем версию из имени ассета (например DroneFlames_Reborn_PC_Setup_v0.33.0.exe)
        if tag == "" or tag.to_lower() == "latest":
                for asset_dict in assets:
                        if asset_dict is Dictionary:
                                var aname: String = String(asset_dict.get("name", ""))
                                var v_start: int = aname.find("_v")
                                if v_start != -1:
                                        var sub: String = aname.substr(v_start + 2)
                                        var v_end: int = sub.find("_")
                                        if v_end != -1:
                                                tag = clean_version_string(sub.substr(0, v_end))
                                                break

        if tag == "" or tag.to_lower() == "latest":
                check_failed.emit("Некорректный релиз на GitHub (отсутствует tag_name)")
                return

        current_version = get_installed_version()
        latest_tag = tag
        latest_changelog = changelog

        if compare_versions(tag, current_version) > 0:
                # Найдена более свежая версия
                var target_url: String = ""
                var target_name: String = ""

                var is_mac: bool = OS.get_name() == "macOS"
                var is_android: bool = OS.has_feature("mobile") or OS.get_name() == "Android"
                for asset_dict in assets:
                        if not (asset_dict is Dictionary):
                                continue
                        var aname: String = String(asset_dict.get("name", ""))
                        var adl: String = String(asset_dict.get("browser_download_url", ""))
                        if is_android:
                                if aname.ends_with(".apk"):
                                        target_url = adl
                                        target_name = aname
                                        break
                        elif is_mac:
                                if aname.ends_with(".dmg") or (aname.contains("macOS") and aname.ends_with(".zip")):
                                        target_url = adl
                                        target_name = aname
                                        if aname.ends_with(".dmg"):
                                                break # Приоритет DMG установщику на Mac
                        else:
                                if aname.ends_with(".exe"):
                                        target_url = adl
                                        target_name = aname
                                        if aname.to_lower().contains("setup"):
                                                break # Нашли именно установщик

                if target_url == "":
                        if is_android:
                                target_url = "https://github.com/%s/%s/releases/download/v%s/DroneFlames_Reborn_v%s_android.apk" % [repo_owner, repo_name, tag, tag]
                                target_name = "DroneFlames_Reborn_v%s_android.apk" % tag
                        elif is_mac:
                                target_url = "https://github.com/%s/%s/releases/download/v%s/DroneFlames_Reborn_macOS_v%s.dmg" % [repo_owner, repo_name, tag, tag]
                                target_name = "DroneFlames_Reborn_macOS_v%s.dmg" % tag
                        else:
                                target_url = "https://github.com/%s/%s/releases/download/v%s/DroneFlames_Reborn_PC_Setup_v%s.exe" % [repo_owner, repo_name, tag, tag]
                                target_name = "DroneFlames_Reborn_PC_Setup_v%s.exe" % tag

                latest_url = target_url
                latest_asset_name = target_name
                is_update_ready = true

                update_available.emit(tag, changelog, target_url, target_name)
        else:
                is_update_ready = false
                no_update_found.emit()

## Скачать файл обновления в папку пользовательских данных
func download_update(download_url: String, file_name: String = "") -> void:
        if download_url == "":
                download_failed.emit("Ссылка на скачивание пуста")
                return

        if file_name == "":
                file_name = download_url.get_file()
                if file_name == "":
                        file_name = "DroneFlames_Update.exe"

        var updates_dir: String = OS.get_user_data_dir() + "/updates"
        DirAccess.make_dir_recursive_absolute(updates_dir)
        _download_path = updates_dir + "/" + file_name

        _http_download.download_file = _download_path
        var headers: PackedStringArray = PackedStringArray([
                "User-Agent: DroneFlames-Reborn"
        ])
        
        _is_downloading = true
        var err: Error = _http_download.request(download_url, headers)
        if err != OK:
                _is_downloading = false
                download_failed.emit("Ошибка при начале скачивания: %d" % err)

func _on_download_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
        _is_downloading = false
        if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
                download_failed.emit("Ошибка скачивания файла: код %d" % response_code)
                return

        download_completed.emit(_download_path)

## Запустить скачанный инсталлятор/образ и выйти из игры
func apply_and_restart(installer_path: String, silent: bool = false) -> void:
        var abs_path: String = ProjectSettings.globalize_path(installer_path)
        if OS.get_name() == "macOS" or OS.has_feature("mobile") or OS.get_name() == "Android":
                OS.shell_open(abs_path)
                get_tree().quit()
                return

        var args: PackedStringArray = PackedStringArray()
        if silent:
                args.append("/SILENT")
        
        var pid: int = OS.create_process(abs_path, args)
        if pid > 0:
                get_tree().quit()
        else:
                push_error("Не удалось запустить инсталлятор: " + abs_path)

## Сравнение двух semver строк (например: "0.33.0" и "0.32.0")
## Возвращает: 1 если v1 > v2, -1 если v1 < v2, 0 если равны
static func compare_versions(v1: String, v2: String) -> int:
        var s1: String = clean_version_string(v1)
        var s2: String = clean_version_string(v2)
        var p1: PackedStringArray = s1.split(".")
        var p2: PackedStringArray = s2.split(".")
        var max_len: int = maxi(p1.size(), p2.size())

        for i in max_len:
                var n1: int = int(p1[i]) if i < p1.size() else 0
                var n2: int = int(p2[i]) if i < p2.size() else 0
                if n1 > n2:
                        return 1
                elif n1 < n2:
                        return -1
        return 0
