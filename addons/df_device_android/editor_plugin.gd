@tool
extends EditorPlugin



var _export: AndroidExport = null


func _enter_tree() -> void :
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void :
	remove_export_plugin(_export)
	_export = null


class AndroidExport extends EditorExportPlugin:
	const DIR: String = "res://addons/df_device_android/bin/"

	func _get_name() -> String:
		return "DFDevice"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var aar: String = DIR + ("df_device-debug.aar" if debug else "df_device-release.aar")
		if not FileAccess.file_exists(aar):
			push_warning("DFDevice: %s is missing (build native/df_device_android): no Play Integrity in this build" % aar)
			return PackedStringArray()
		return PackedStringArray([aar.trim_prefix("res://addons/")])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["com.google.android.play:integrity:1.4.0", "androidx.security:security-crypto:1.1.0-alpha06"])
