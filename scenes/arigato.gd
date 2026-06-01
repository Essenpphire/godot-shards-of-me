extends Control

@onready var bg: ColorRect = $Bg
@onready var title_label: Label = $TitleLabel
@onready var credits_container: VBoxContainer = $CreditsContainer
@onready var special_thanks: VBoxContainer = $SpecialThanks

@export var bgm : AudioStream
@export var title_fade_in_duration: float = 1.5
@export var title_fade_out_duration: float = 1.0
@export var credits_scroll_duration: float = 18.0
@export var line_interval: float = 0.8

func _ready() -> void:
	if is_instance_valid(UiLayer):
		UiLayer.hide_gameplay_ui()
	if bgm:
		Audio.set_volume(0, 0.1)
		Audio.play_music(bgm)
		
	title_label.show()
	credits_container.show()
	special_thanks.show()
		
	var viewport_size = get_viewport_rect().size
	size = viewport_size
	bg.size = viewport_size

	title_label.position.x = (viewport_size.x - title_label.size.x) / 2
	title_label.position.y = viewport_size.y * 0.35
	title_label.modulate.a = 0.0

	var credits_height = 882
	credits_container.position.x = (viewport_size.x - credits_container.size.x) / 2
	credits_container.position.y = viewport_size.y + 50

	special_thanks.position.x = (viewport_size.x - special_thanks.size.x) / 2
	special_thanks.position.y = (viewport_size.y - special_thanks.get_combined_minimum_size().y) / 2
	_special_thanks_set_alpha(0.0)
	special_thanks.hide()

	_start_sequence(viewport_size, credits_height)

func _start_sequence(viewport_size: Vector2, credits_height: float) -> void:
	await _fade_title_in()
	await _scroll_credits(viewport_size, credits_height)
	await _play_special_thanks()
	await get_tree().create_timer(2.0).timeout
	await _finish()

func _fade_title_in() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, title_fade_in_duration)
	await tween.finished

func _scroll_credits(viewport_size: Vector2, credits_height: float) -> void:
	var end_y = -credits_height
	var tween1 = get_tree().create_tween()
	tween1.tween_interval(1.5)
	tween1.tween_property(title_label, "modulate:a", 0.0, title_fade_out_duration)
	var tween2 = get_tree().create_tween()
	tween2.set_ease(Tween.EASE_IN_OUT)
	tween2.set_trans(Tween.TRANS_LINEAR)
	tween2.tween_property(credits_container, "position:y", end_y, credits_scroll_duration)
	await tween2.finished

func _play_special_thanks() -> void:
	credits_container.hide()
	special_thanks.show()

	var lines = special_thanks.get_children()
	for line in lines:
		if line is Label:
			line.modulate.a = 0.0

	for i in range(lines.size()):
		var line = lines[i]
		if not (line is Label):
			continue

		var _fade_in_time
		if i == lines.size() - 1:
			_fade_in_time = 3.0
		else:
			_fade_in_time = 2.0
		var fade_in = get_tree().create_tween()
		fade_in.tween_property(line, "modulate:a", 1.0, _fade_in_time)
		await fade_in.finished

	await get_tree().create_timer(1.0).timeout

func _finish() -> void:
	Data.delete_save()
	GameManager.back_to_menu()

func _special_thanks_set_alpha(alpha: float) -> void:
	for child in special_thanks.get_children():
		if child is Label:
			child.modulate.a = alpha

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_finish()
