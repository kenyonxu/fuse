extends Node

func _ready():
    test_unit_conversions()
    test_player_detection()
    test_player_creation()
    print("✓ AudioUtils tests passed")

func test_unit_conversions():
    # Linear to DB
    assert(abs(AudioUtils.linear_to_db(1.0) - 0.0) < 0.01, "1.0 linear = 0 dB")
    assert(AudioUtils.linear_to_db(0.5) < 0, "0.5 linear should be negative dB")
    assert(AudioUtils.linear_to_db(2.0) > 0, "2.0 linear should be positive dB")

    # DB to Linear
    assert(abs(AudioUtils.db_to_linear(0.0) - 1.0) < 0.01, "0 dB = 1.0 linear")

    # Pitch scale from semitones
    var pitch_up = AudioUtils.get_pitch_scale_from_semitones(12.0)
    assert(abs(pitch_up - 2.0) < 0.01, "12 semitones = 2.0 pitch scale")

    var pitch_down = AudioUtils.get_pitch_scale_from_semitones(-12.0)
    assert(abs(pitch_down - 0.5) < 0.01, "-12 semitones = 0.5 pitch scale")

    print("  ✓ Unit conversions test passed")

func test_player_detection():
    var node_2d = Node2D.new()
    var node_3d = Node3D.new()
    var node_generic = Node.new()

    var type_2d = AudioUtils.detect_player_type(node_2d)
    var type_3d = AudioUtils.detect_player_type(node_3d)
    var type_generic = AudioUtils.detect_player_type(node_generic)

    assert(type_2d == 0, "Node2D should be PLAYER_2D (0)")
    assert(type_3d == 1, "Node3D should be PLAYER_3D (1)")
    assert(type_generic == 0, "Generic node should default to PLAYER_2D (0)")

    node_2d.queue_free()
    node_3d.queue_free()
    node_generic.queue_free()

    print("  ✓ Player detection test passed")

func test_player_creation():
    var player_2d = AudioUtils.create_player_2d()
    assert(player_2d is AudioStreamPlayer2D, "Should create 2D player")
    player_2d.queue_free()

    var player_3d = AudioUtils.create_player_3d()
    assert(player_3d is AudioStreamPlayer3D, "Should create 3D player")
    player_3d.queue_free()

    print("  ✓ Player creation test passed")