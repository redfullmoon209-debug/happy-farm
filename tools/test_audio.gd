extends SceneTree
# Audio regression gate for the playable Godot Web build.
var failures: int = 0

func check(okay: bool, detail: String) -> void:
    if not okay:
        failures += 1
        printerr("AUDIO TEST FAIL: " + detail)

func _initialize() -> void:
    call_deferred("_run_audio_checks")

func _run_audio_checks() -> void:
    var scene: PackedScene = load("res://scenes/Main.tscn")
    check(scene != null, "Happy Farm scene exists")
    if scene == null:
        quit(1)
        return
    var game: Variant = scene.instantiate()
    root.add_child(game)
    var audio: Variant = game.farm_audio
    check(audio != null, "FarmAudio is attached to the game")
    if audio == null:
        quit(1)
        return
    check(audio.is_ready(), "theme, eight Foley sounds and three Thai voice files are loaded")
    check(audio.music.stream != null, "background music stream available")
    check(audio.music.stream.get_length() > 15.0, "original music has a real multi-bar melody")
    check(audio.loaded_effects.size() == 8, "all activity SFX present")
    check(audio.loaded_voices.size() == 3, "all three voice recordings present")
    check(game.audio_button != null and game.audio_button.is_visible_in_tree(), "phone sound button visible")
    check(game.voice_caption != null and game.voice_caption_label != null, "Thai accessibility caption available")

    audio.activate()
    check(audio.unlocked, "first click/touch can unlock background audio")
    check(audio.music.stream != null, "music remains available after unlock")
    for sound in ["till", "plant", "water", "harvest", "buy", "pig", "jump", "step"]:
        check(audio.loaded_effects.has(sound), "Foley exists: " + sound)
        audio.play_effect(sound)

    for phrase in ["plant", "water", "harvest"]:
        check(audio.loaded_voices.has(phrase), "Thai voice exists: " + phrase)
        if audio.loaded_voices.has(phrase):
            check(audio.loaded_voices[phrase].get_length() > 0.6, "speech is actually recorded: " + phrase)
            audio.voice.stop()
            audio.announce(phrase, true)
            check(not game.voice_caption_label.text.is_empty(), "Thai speech has a visible subtitle")
    check(game.voice_caption.visible, "dialogue subtitle becomes visible")

    audio.set_enabled(false)
    check(not audio.enabled, "mute sound works")
    check(not audio.music.playing, "music stops when muted")
    audio.set_enabled(true)
    check(audio.enabled, "unmute sound works")
    game.refresh_sound_button()
    check(game.audio_button.text == "เสียง: เปิด", "Thai sound button updates correctly")

    if failures == 0:
        print("AUDIO TESTS PASS: music, Foley, recorded Thai speech, subtitles and browser sound toggle")
        quit(0)
    else:
        printerr("%d audio checks failed" % failures)
        quit(1)
