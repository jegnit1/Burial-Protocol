@echo off
set "GODOT=C:\Users\jegnit\Desktop\Godot_v4.6.1-stable_win64.exe"
set "PROJECT=C:\Users\jegnit\Desktop\Burial Protocol\burial-protocol"
set "LOG_FILE=%PROJECT%\godot_data_pipeline.log"

"%GODOT%" --headless --log-file "%LOG_FILE%" --path "%PROJECT%" --script res://scripts/tools/data_pipeline/DataPipelineCli.gd -- sync_all_tsv --output_dir=res://data_tsv

pause
