extends Control
class_name MenuBackground

var pulse_time: float = 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func _draw() -> void:
	var screen_rect := Rect2(Vector2.ZERO, size)
	draw_rect(screen_rect, Color(0.05, 0.07, 0.11), true)

	# Soft layered bands to keep menu readable but non-flat.
	for i in range(6):
		var y := size.y * (float(i) / 5.0)
		var wave := sin(pulse_time * 0.5 + i * 0.8) * 28.0
		var band := Rect2(Vector2(-120.0, y + wave), Vector2(size.x + 240.0, 36.0))
		var alpha := 0.04 + 0.02 * float(i % 2)
		draw_rect(band, Color(0.22, 0.35, 0.50, alpha), true)

	var center := size * 0.5
	for r: float in PackedFloat32Array([120.0, 190.0, 260.0, 340.0]):
		var pulse := r + sin(pulse_time * 0.9 + r * 0.01) * 8.0
		draw_arc(center, pulse, 0.0, TAU, 96, Color(0.55, 0.75, 0.96, 0.12), 2.0)

	# Minimal icon motif.
	_draw_signal_icon(center + Vector2(0.0, -130.0))

func _draw_signal_icon(origin: Vector2) -> void:
	var left := origin + Vector2(-54.0, 0.0)
	var middle := origin
	var right := origin + Vector2(54.0, 0.0)

	draw_circle(left, 12.0, Color(0.22, 0.72, 1.0, 0.95))
	draw_circle(middle, 12.0, Color(0.95, 0.95, 1.0, 0.95))
	draw_circle(right, 12.0, Color(1.0, 0.45, 0.45, 0.95))
	draw_line(left, middle, Color(0.90, 0.93, 1.0, 0.8), 4.0)
	draw_line(middle, right, Color(0.90, 0.93, 1.0, 0.8), 4.0)
