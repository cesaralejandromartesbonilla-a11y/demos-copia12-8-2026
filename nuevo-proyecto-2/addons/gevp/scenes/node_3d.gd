# vehicle_base.gd
extends Node3D

var is_occupied = false

func can_mount() -> bool:
	return not is_occupied

func on_player_mounted(player: CharacterBody3D) -> void:
	is_occupied = true
	# Aquí activas controles, cámara, etc.

func on_player_unmounted() -> void:
	is_occupied = false
