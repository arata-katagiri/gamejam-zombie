extends Node

signal zone_entered(zone_type: String)
signal zone_exited()
signal player_damaged(amount: float)
signal player_healed(amount: float)
signal player_died()
signal loot_collected(item_name: String, quantity: int)
signal player_entered_car()
signal player_exited_car()
signal car_travel_started()
signal car_travel_ended()
signal zone_cleared()
signal game_over()

# New signals for world diversity
signal biome_changed(biome_name: String)
signal road_event_triggered(event_type: String)
signal zone_type_spawned(zone_type: String)
