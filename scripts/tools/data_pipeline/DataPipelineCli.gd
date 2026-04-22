extends SceneTree

const TSV_SCHEMA = preload("res://scripts/tools/data_pipeline/TsvSchema.gd")
const EXPORT_SERVICE_SCRIPT = preload("res://scripts/tools/data_pipeline/TsvExportService.gd")
const CONVERTER_SCRIPT = preload("res://scripts/tools/data_pipeline/TsvToTresConverter.gd")


func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.is_empty():
		_print_help()
		quit()
		return
	var command := str(user_args[0])
	var options := _parse_options(user_args.slice(1))
	match command:
		"export_tsv":
			_run_export_tsv(options)
		"convert_tsv":
			_run_convert_tsv(options)
		"sync_all_tsv":
			_run_sync_all_tsv(options)
		_:
			push_error("Unknown command: %s. JSON commands were removed; use export_tsv / convert_tsv / sync_all_tsv." % command)
			_print_help()
			quit(1)


func _run_export_tsv(options: Dictionary) -> void:
	var output_dir := str(options.get("output_dir", TSV_SCHEMA.DEFAULT_TSV_DIR))
	var export_service = EXPORT_SERVICE_SCRIPT.new()
	var result := export_service.export_all_catalogs(output_dir)
	if not bool(result.get("ok", false)):
		for error_text in result.get("errors", []):
			push_error(str(error_text))
		quit(1)
		return
	for file_path in result.get("written_files", []):
		print("Exported TSV: ", file_path)
	quit()


func _run_convert_tsv(options: Dictionary) -> void:
	var input_dir := str(options.get("input_dir", TSV_SCHEMA.DEFAULT_TSV_DIR))
	var catalog := str(options.get("catalog", "all"))
	var converter = CONVERTER_SCRIPT.new()
	var result := {}
	if catalog == "all":
		result = converter.convert_all_from_directory(input_dir)
	else:
		result = converter.convert_catalog_from_directory(input_dir, catalog)
	_print_result_and_quit(result)


func _run_sync_all_tsv(options: Dictionary) -> void:
	var output_dir := str(options.get("output_dir", TSV_SCHEMA.DEFAULT_TSV_DIR))
	var export_service = EXPORT_SERVICE_SCRIPT.new()
	var export_result := export_service.export_all_catalogs(output_dir)
	if not bool(export_result.get("ok", false)):
		for error_text in export_result.get("errors", []):
			push_error(str(error_text))
		quit(1)
		return
	var converter = CONVERTER_SCRIPT.new()
	var result := converter.convert_all_from_directory(output_dir)
	_print_result_and_quit(result)


func _print_result_and_quit(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		for file_path in result.get("written_paths", []):
			print("Conversion complete: ", file_path)
		quit()
		return
	for error_text in result.get("errors", []):
		push_error(str(error_text))
	quit(1)


func _parse_options(raw_args: Array) -> Dictionary:
	var options: Dictionary = {}
	for raw_arg in raw_args:
		var arg := str(raw_arg)
		if not arg.begins_with("--"):
			continue
		var key_value := arg.substr(2)
		var separator_index := key_value.find("=")
		if separator_index == -1:
			options[key_value] = "true"
			continue
		var key := key_value.substr(0, separator_index)
		var value := key_value.substr(separator_index + 1)
		options[key] = value
	return options


func _print_help() -> void:
	print("DataPipelineCli usage:")
	print("  godot --headless --path <project> --script res://scripts/tools/data_pipeline/DataPipelineCli.gd -- export_tsv --output_dir=res://data_tsv")
	print("  godot --headless --path <project> --script res://scripts/tools/data_pipeline/DataPipelineCli.gd -- convert_tsv --input_dir=res://data_tsv")
	print("  godot --headless --path <project> --script res://scripts/tools/data_pipeline/DataPipelineCli.gd -- convert_tsv --input_dir=res://data_tsv --catalog=shop_item_catalog")
	print("  godot --headless --path <project> --script res://scripts/tools/data_pipeline/DataPipelineCli.gd -- sync_all_tsv --output_dir=res://data_tsv")
