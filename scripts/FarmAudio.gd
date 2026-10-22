extends Node
# Happy Farm audio: original looped soundtrack + Foley + recorded Thai voice.
# Real voice files are kept in assets/audio (no browser-specific TTS required).
# Browsers allow sound to begin only after a player gesture.
signal subtitle(text: String)

const DIRECTORY: String = "res://assets/audio/"
const VOICES: Dictionary = {
    "plant": "voice_plant.mp3",
    "water": "voice_water.mp3",
    "harvest": "voice_harvest.mp3"
}
const PHRASES: Dictionary = {
    "plant": "โอ๊ย ฉันอยากปลูกผักจังเลย",
    "water": "รดน้ำหน่อยจ้า",
    "harvest": "เก็บเกี่ยวได้แล้วจ้า เอาไปขายจ้า"
}
const EFFECTS: Dictionary = {
    "till": "fx_till.wav",
    "plant": "fx_plant.wav",
    "water": "fx_water.wav",
    "harvest": "fx_harvest.wav",
    "buy": "fx_coin.wav",
    "pig": "fx_pig.wav",
    "jump": "fx_jump.wav",
    "step": "fx_step.wav"
}

var enabled: bool = true
var unlocked: bool = false
var music: AudioStreamPlayer
var voice: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var loaded_effects: Dictionary = {}
var loaded_voices: Dictionary = {}
var play_time: float = 0.0
var last_voice_time: float = -1000.0
var last_by_phrase: Dictionary = {}
var queued_phrase: String = ""
var voice_active_key: String = ""
var load_error_count: int = 0

func _ready() -> void:
    var preferences: ConfigFile = ConfigFile.new()
    if preferences.load("user://happy_farm_audio.cfg") == OK:
        enabled = bool(preferences.get_value("sound", "enabled", true))
    music = AudioStreamPlayer.new()
    music.name = "BackgroundFarmMusic"
    music.volume_db = -15.0
    add_child(music)

    voice = AudioStreamPlayer.new()
    voice.name = "ThaiFarmerVoice"
    voice.volume_db = -2.0
    add_child(voice)
    voice.finished.connect(_on_voice_finished)

    for i in range(5):
        var player: AudioStreamPlayer = AudioStreamPlayer.new()
        player.name = "FarmEffect%d" % i
        player.volume_db = -7.0
        add_child(player)
        sfx_players.append(player)

    for key in EFFECTS.keys():
        var effect: AudioStream = _read_sound(str(EFFECTS[key]))
        if effect != null:
            loaded_effects[key] = effect
    for key in VOICES.keys():
        var sentence: AudioStream = _read_sound(str(VOICES[key]))
        if sentence != null:
            loaded_voices[key] = sentence

    music.stream = _read_sound("farm_theme.wav")
    if music.stream is AudioStreamWAV:
        var track: AudioStreamWAV = music.stream as AudioStreamWAV
        track.loop_mode = AudioStreamWAV.LOOP_FORWARD
        track.loop_begin = 0
        track.loop_end = track.data.size() / 2

func _read_sound(filename: String) -> AudioStream:
    var path: String = DIRECTORY + filename
    if not ResourceLoader.exists(path):
        load_error_count += 1
        push_warning("Missing Happy Farm audio file: " + path)
        return null
    var resource: Resource = ResourceLoader.load(path)
    if resource is AudioStream:
        return resource as AudioStream
    load_error_count += 1
    push_warning("Invalid audio asset: " + path)
    return null

func _process(delta: float) -> void:
    play_time += delta

func activate() -> void:
    # Called from direct pointer/key interaction so Chrome/Android/iOS may unlock audio.
    if unlocked:
        return
    unlocked = true
    if enabled:
        start_music()

func start_music() -> void:
    if not enabled or not unlocked or music.stream == null:
        return
    if not music.playing:
        music.play()

func set_enabled(new_value: bool) -> void:
    enabled = new_value
    var preferences: ConfigFile = ConfigFile.new()
    preferences.set_value("sound", "enabled", enabled)
    preferences.save("user://happy_farm_audio.cfg")
    if enabled:
        activate()
        start_music()
    else:
        music.stop()
        voice.stop()
        for effect_player in sfx_players:
            effect_player.stop()
        queued_phrase = ""

func play_effect(key: String) -> void:
    if not enabled or not unlocked or not loaded_effects.has(key):
        return
    var selected: AudioStreamPlayer = null
    for player in sfx_players:
        if not player.playing:
            selected = player
            break
    if selected == null:
        selected = sfx_players[0]
    selected.stream = loaded_effects[key]
    selected.volume_db = -11.0 if key == "step" else (-8.0 if key == "pig" else -5.0)
    selected.pitch_scale = 0.97 + float(randi_range(0, 6)) / 100.0
    selected.play()

func announce(key: String, immediate: bool = false) -> bool:
    if not enabled or not unlocked or not PHRASES.has(key):
        return false
    var delay: float = 45.0 if key == "plant" else (24.0 if key == "water" else 30.0)
    var last: float = float(last_by_phrase.get(key, -1000.0))
    if not immediate and play_time - last < delay:
        return false
    if not immediate and play_time - last_voice_time < 8.0:
        return false
    if voice.playing:
        if immediate and key != voice_active_key:
            queued_phrase = key
        return false
    _speak_now(key)
    return true

func _speak_now(key: String) -> void:
    last_by_phrase[key] = play_time
    last_voice_time = play_time
    voice_active_key = key
    subtitle.emit(str(PHRASES[key]))
    if loaded_voices.has(key):
        voice.stream = loaded_voices[key]
        voice.play()
        music.volume_db = -24.0
    else:
        # Silence is preferable to browser-dependent mispronounced fallback.
        # The Thai subtitle still displays even when a voice file is missing.
        voice_active_key = ""

func _on_voice_finished() -> void:
    music.volume_db = -15.0
    voice_active_key = ""
    if not enabled:
        queued_phrase = ""
        return
    if not queued_phrase.is_empty():
        var next: String = queued_phrase
        queued_phrase = ""
        _speak_now(next)

func is_ready() -> bool:
    return music.stream != null and loaded_effects.size() == EFFECTS.size() and loaded_voices.size() == VOICES.size()
