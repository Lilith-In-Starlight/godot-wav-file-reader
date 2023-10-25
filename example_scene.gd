extends Node


func _ready() -> void:
	$AudioStreamPlayer.stream = WAVFileReader.load("res://stranger_eons_pandoras_tower.waav").result
	$AudioStreamPlayer.play()