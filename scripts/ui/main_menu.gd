extends Control

## MainMenu — Stylish title screen for The Road.

var title_label: Label
var subtitle_label: Label
var play_button: Button
var quit_button: Button
var backdrop: ColorRect
var vignette: ColorRect
var particles_timer: float = 0.0
var particle_rects: Array[ColorRect] = []

func _ready():
	# Reset GameManager state for a fresh run
	GameManager.reset_run()

	# Tell SoundManager we're in the menu (stop gameplay sounds, keep music)
	if has_node("/root/SoundManager"):
		SoundManager.enter_menu()
		SoundManager.resume_music()

	_build_ui()

func _build_ui():
	# Full-screen dark backdrop
	backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.04, 0.08, 1.0)
	add_child(backdrop)

	# Animated ambient particles (floating dust/embers)
	for i in range(30):
		var p = ColorRect.new()
		p.size = Vector2(randf_range(1, 3), randf_range(1, 3))
		p.position = Vector2(randf_range(0, 1280), randf_range(0, 720))
		p.color = Color(0.8, 0.4, 0.2, randf_range(0.1, 0.4))
		p.z_index = 1
		add_child(p)
		particle_rects.append(p)

	# Vignette overlay
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.z_index = 2
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float dist = distance(UV, vec2(0.5, 0.5));
	float vig = smoothstep(0.3, 0.9, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vig * 0.7);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	vignette.material = mat
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	# Center container for menu content
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-200, -180)
	center.custom_minimum_size = Vector2(400, 360)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 20)
	center.z_index = 10
	add_child(center)

	# Title
	title_label = Label.new()
	title_label.text = "THE ROAD"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title_label.add_theme_color_override("font_outline_color", Color(0.6, 0.2, 0.1))
	title_label.add_theme_constant_override("outline_size", 4)
	center.add_child(title_label)

	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.text = "Survive. Scavenge. Keep Moving."
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
	center.add_child(subtitle_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 40
	center.add_child(spacer)

	# Play button
	play_button = _create_menu_button("PLAY", Color(0.2, 0.65, 0.35))
	play_button.pressed.connect(_on_play)
	center.add_child(play_button)

	# Quit button
	quit_button = _create_menu_button("QUIT", Color(0.65, 0.2, 0.2))
	quit_button.pressed.connect(_on_quit)
	center.add_child(quit_button)

	# Version label
	var version_label = Label.new()
	version_label.text = "v1.0 — Game Jam Build"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	center.add_child(version_label)
	
	# Controls hint at bottom
	var controls_container = MarginContainer.new()
	controls_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	controls_container.add_theme_constant_override("margin_bottom", 30)
	controls_container.z_index = 10
	add_child(controls_container)
	
	var controls_label = Label.new()
	controls_label.text = "WASD — Move  |  SHIFT — Sprint  |  LMB — Attack  |  E — Interact  |  Q — Switch Weapon  |  TAB — Backpack"
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.add_theme_font_size_override("font_size", 13)
	controls_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	controls_container.add_child(controls_label)

	# Fade-in animation
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.8)

func _create_menu_button(text: String, accent_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 55)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.1, 0.14, 0.9)
	normal_style.border_color = accent_color * 0.7
	normal_style.set_border_width_all(2)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.content_margin_left = 20
	normal_style.content_margin_right = 20
	normal_style.content_margin_top = 12
	normal_style.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = accent_color * 0.4
	hover_style.border_color = accent_color
	hover_style.set_border_width_all(3)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = accent_color * 0.6
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Focus style (for keyboard navigation)
	var focus_style = hover_style.duplicate()
	btn.add_theme_stylebox_override("focus", focus_style)

	return btn

func _process(delta: float):
	# Animate particles
	particles_timer += delta
	for p in particle_rects:
		p.position.y -= delta * randf_range(5, 20)
		p.position.x += sin(particles_timer * randf_range(0.5, 2.0)) * delta * 8.0
		p.modulate.a = 0.3 + 0.3 * sin(particles_timer * randf_range(1.0, 3.0))
		# Wrap around
		if p.position.y < -5:
			p.position.y = 725
			p.position.x = randf_range(0, 1280)

	# Subtle title breathing
	if title_label:
		var breath = 1.0 + sin(particles_timer * 1.5) * 0.015
		title_label.scale = Vector2(breath, breath)

func _on_play():
	# Disable buttons to prevent double-clicks
	play_button.disabled = true
	quit_button.disabled = true

	# Fade out then load game
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)

func _on_quit():
	get_tree().quit()
