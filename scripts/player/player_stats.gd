extends Node

signal stats_changed()
signal stat_depleted(stat_name: String)

const MAX_HEALTH := 100.0
const MAX_HUNGER := 100.0
const MAX_ENERGY := 100.0
const HUNGER_DRAIN_RATE := 1.0
const HUNGER_DAMAGE_RATE := 5.0
const ENERGY_REGEN_RATE := 3.0

var health: float = MAX_HEALTH
var hunger: float = MAX_HUNGER
var energy: float = MAX_ENERGY

func _process(delta: float):
	_drain_hunger(delta)
	_regen_energy(delta)

func _drain_hunger(delta: float):
	hunger = max(0.0, hunger - HUNGER_DRAIN_RATE * delta)
	if hunger <= 0.0:
		take_damage(HUNGER_DAMAGE_RATE * delta)
	stats_changed.emit()

func _regen_energy(delta: float):
	if energy < MAX_ENERGY:
		energy = min(MAX_ENERGY, energy + ENERGY_REGEN_RATE * delta)
		stats_changed.emit()

func take_damage(amount: float):
	health = max(0.0, health - amount)
	stats_changed.emit()
	if health <= 0.0:
		stat_depleted.emit("health")
		SignalsBus.player_died.emit()

func heal(amount: float):
	health = min(MAX_HEALTH, health + amount)
	stats_changed.emit()
	SignalsBus.player_healed.emit(amount)

func feed(amount: float):
	hunger = min(MAX_HUNGER, hunger + amount)
	stats_changed.emit()

func restore_energy(amount: float):
	energy = min(MAX_ENERGY, energy + amount)
	stats_changed.emit()

func use_energy(amount: float) -> bool:
	if energy >= amount:
		energy -= amount
		stats_changed.emit()
		return true
	return false

func get_health_percent() -> float:
	return health / MAX_HEALTH

func get_hunger_percent() -> float:
	return hunger / MAX_HUNGER

func get_energy_percent() -> float:
	return energy / MAX_ENERGY
