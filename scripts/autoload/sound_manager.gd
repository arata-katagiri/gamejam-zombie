extends Node

## SoundManager — Central audio controller.
## Manages background music, footsteps, gunshots, and zombie sounds.
## Persists across scenes as an autoload.

# ─── Audio Players ───
var music_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var gunshot_player: AudioStreamPlayer
var zombie_player: AudioStreamPlayer

# ─── Audio Streams ───
var music_stream: AudioStream
var footstep_stream: AudioStream
var gunshot_stream: AudioStream
var zombie_stream: AudioStream

# ─── State ───
var footstep_timer: float = 0.0
var zombie_ambient_timer: float = 0.0
var _music_playing: bool = false
var _in_game: bool = false  # True when running in the main game scene (not menu)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Load audio streams
	music_stream = load("res://sounds/creepy-background-music.mp3")
	footstep_stream = load("res://sounds/footsteps.mp3")
	gunshot_stream = load("res://sounds/gunshot.mp3")
	zombie_stream = load("res://sounds/zombie-sound.mp3")

	# Background music player
	music_player = AudioStreamPlayer.new()
	music_player.stream = music_stream
	music_player.volume_db = -12.0
	music_player.bus = "Master"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)

	# Footstep player
	footstep_player = AudioStreamPlayer.new()
	footstep_player.stream = footstep_stream
	footstep_player.volume_db = -8.0
	footstep_player.bus = "Master"
	add_child(footstep_player)

	# Gunshot player
	gunshot_player = AudioStreamPlayer.new()
	gunshot_player.stream = gunshot_stream
	gunshot_player.volume_db = -4.0
	gunshot_player.bus = "Master"
	add_child(gunshot_player)

	# Zombie ambient player
	zombie_player = AudioStreamPlayer.new()
	zombie_player.stream = zombie_stream
	zombie_player.volume_db = -10.0
	zombie_player.bus = "Master"
	add_child(zombie_player)

	# Start background music immediately (plays during menu too)
	_start_music()

	# Initialize zombie ambient timer
	zombie_ambient_timer = randf_range(8.0, 20.0)

func _start_music():
	if music_player and music_stream:
		music_player.play()
		_music_playing = true
		# Loop music when finished
		if not music_player.finished.is_connected(_on_music_finished):
			music_player.finished.connect(_on_music_finished)

func _on_music_finished():
	if music_player:
		music_player.play()
		_music_playing = true

func _process(delta: float):
	if GameManager.current_state == GameManager.GameState.GAME_OVER:
		return

	# Only process gameplay sounds when in-game
	if _in_game:
		_handle_footsteps(delta)
		_handle_zombie_ambient(delta)

func _handle_footsteps(delta: float):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		if footstep_player.playing:
			footstep_player.stop()
		return

	# Only play footsteps when player is walking/running on foot
	var is_moving = player.velocity.length() > 10.0 and player.current_state != player.State.IN_CAR and player.current_state != player.State.DEAD

	if is_moving:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			if not footstep_player.playing:
				footstep_player.play()
			# Interval depends on speed: faster = shorter interval
			var is_running = Input.is_key_pressed(KEY_SHIFT)
			footstep_timer = 0.35 if is_running else 0.5
	else:
		if footstep_player.playing:
			footstep_player.stop()
		footstep_timer = 0.0

func _handle_zombie_ambient(delta: float):
	zombie_ambient_timer -= delta
	if zombie_ambient_timer <= 0.0:
		# Play zombie sound if there are zombies visible on camera
		var cam = get_viewport().get_camera_2d()
		var zombies = get_tree().get_nodes_in_group("zombie")

		if cam and zombies.size() > 0:
			var vp_size = get_viewport().get_visible_rect().size
			var cam_zoom = cam.zoom
			# Calculate the visible area in world coordinates
			var half_w = (vp_size.x / cam_zoom.x) * 0.5
			var half_h = (vp_size.y / cam_zoom.y) * 0.5
			var cam_pos = cam.global_position
			var view_rect = Rect2(cam_pos.x - half_w, cam_pos.y - half_h, half_w * 2.0, half_h * 2.0)

			var nearest_dist: float = 1e9
			var found_visible = false
			for z in zombies:
				if is_instance_valid(z) and z.current_state != z.State.DEAD:
					if view_rect.has_point(z.global_position):
						found_visible = true
						var d = cam_pos.distance_to(z.global_position)
						if d < nearest_dist:
							nearest_dist = d

			if found_visible:
				# Volume scales with proximity to camera center
				var max_view_dist = half_w  # Use half viewport width as max distance
				var proximity = 1.0 - clamp(nearest_dist / max_view_dist, 0.0, 1.0)
				zombie_player.volume_db = lerp(-20.0, -6.0, proximity)
				if not zombie_player.playing:
					zombie_player.play()

		# Random interval for next zombie ambient sound
		zombie_ambient_timer = randf_range(5.0, 14.0)

## Called when entering the game scene to enable gameplay sounds.
func enter_game():
	_in_game = true

## Called when returning to menu to disable gameplay sounds.
func enter_menu():
	_in_game = false
	# Stop gameplay sounds but keep music
	if footstep_player and footstep_player.playing:
		footstep_player.stop()
	if zombie_player and zombie_player.playing:
		zombie_player.stop()

## Called externally when the player shoots.
func play_gunshot():
	if gunshot_player and gunshot_stream:
		gunshot_player.pitch_scale = 1.0
		gunshot_player.volume_db = -4.0
		gunshot_player.play()

## Stop all audio (for cleanup/transitions).
func stop_all():
	if music_player: music_player.stop()
	if footstep_player: footstep_player.stop()
	if gunshot_player: gunshot_player.stop()
	if zombie_player: zombie_player.stop()
	_music_playing = false

## Resume background music.
func resume_music():
	if music_player and not music_player.playing:
		music_player.play()
		_music_playing = true

