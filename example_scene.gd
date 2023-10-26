extends Node


func _ready() -> void:
	$AudioStreamPlayer.stream = WAVFileReader.load("res://stranger_eons_pandoras_tower.wav").result
	$AudioStreamPlayer.play()

	