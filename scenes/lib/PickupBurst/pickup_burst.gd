extends CPUParticles3D
@export var extra_linger: float = 0.15

func play_and_free() -> void:
    emitting = false        # reset just in case
    emitting = true         # fire one-shot
    get_tree().create_timer(lifetime + extra_linger).timeout.connect(queue_free)
