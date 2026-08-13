class_name VehicleController
extends RigidBody2D

signal died(reason: String)
signal fuel_changed(current: float, max_value: float)

@export var stats: VehicleStats

@onready var _wheel_back: VehicleWheel = $WheelBack
@onready var _wheel_front: VehicleWheel = $WheelFront

var is_alive: bool = true
var fuel_current: float = 100.0
var fuel_max: float = 100.0

var _wheels: Array[VehicleWheel] = []


func _ready() -> void:
	if stats == null:
		stats = VehicleStats.new()

	fuel_max = stats.fuel_capacity
	fuel_current = fuel_max
	fuel_changed.emit(fuel_current, fuel_max)

	_wheel_back.drive_share = 0.55
	_wheel_front.drive_share = 0.45

	for wheel: VehicleWheel in [_wheel_back, _wheel_front]:
		wheel.apply_from_stats(stats)
		_wheels.append(wheel)

	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector2(-4.0, 10.0)
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE


func apply_stats(new_stats: VehicleStats) -> void:
	stats = new_stats
	fuel_max = stats.fuel_capacity
	fuel_current = fuel_max

	for wheel: VehicleWheel in _wheels:
		wheel.apply_from_stats(stats)

	fuel_changed.emit(fuel_current, fuel_max)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	var gas := Input.get_action_strength("gas")
	var brake := Input.get_action_strength("brake")

	_consume_fuel(delta, gas)
	if not is_alive:
		return

	var grounded := false
	for wheel: VehicleWheel in _wheels:
		wheel.update_physics(self, gas, brake, stats.engine_force, stats.brake_force, stats.grip)
		grounded = grounded or wheel.is_grounded

	if not grounded:
		var air_input := gas - brake
		if not is_zero_approx(air_input):
			var facing := signf(cos(rotation))
			if is_zero_approx(facing):
				facing = 1.0
			apply_torque(air_input * stats.air_torque * facing)


func is_grounded() -> bool:
	for wheel: VehicleWheel in _wheels:
		if wheel.is_grounded:
			return true
	return false


func add_fuel(amount: float) -> void:
	if not is_alive:
		return

	fuel_current = minf(fuel_max, fuel_current + amount)
	fuel_changed.emit(fuel_current, fuel_max)


func get_fuel_ratio() -> float:
	if fuel_max <= 0.0:
		return 0.0
	return fuel_current / fuel_max


func die(reason: String) -> void:
	if not is_alive:
		return

	is_alive = false
	freeze = true
	died.emit(reason)


func _consume_fuel(delta: float, gas: float) -> void:
	var consumption: float = stats.fuel_idle_rate * delta
	if gas > 0.0:
		consumption += stats.fuel_accel_rate * gas * delta

	fuel_current = maxf(0.0, fuel_current - consumption)
	fuel_changed.emit(fuel_current, fuel_max)

	if fuel_current <= 0.0:
		die("fuel")


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.angular_velocity = clampf(
		state.angular_velocity,
		-stats.max_angular_velocity,
		stats.max_angular_velocity,
	)
