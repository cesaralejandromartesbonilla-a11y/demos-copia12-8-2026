# src/autoload/game_events.gd
extends Node

signal bloon_popped(gold_earned: int)
signal bloon_reached_end(damage_to_base: int)
signal tower_placed(tower_data: TowerData)
signal tower_selected(tower: TowerBase)
signal tower_deselected()
signal tower_upgraded(tower: TowerBase)
signal tower_sold(tower: TowerBase)
signal wave_started(wave_number: int)
signal wave_finished()
signal request_tower_placement(tower_data: TowerData)
signal ability_activated(tower: TowerBase, ability_name: String)
signal ability_deactivated(tower: TowerBase)
