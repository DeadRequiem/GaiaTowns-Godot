# AudioManager
extends Node

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# Music track
var music_tracks: Dictionary = {
	"default": "res://assets/audio/1_bgMusic.mp3",
	"halloween": "res://assets/audio/2_bgMusicHalloween.mp3",
	"ghost": "res://assets/audio/3_bgMusicGhost.mp3",
	"christmas": "res://assets/audio/4_bgMusicChristmas.mp3",}

# Current state
var current_track: String = ""
var music_enabled: bool = true
var sfx_enabled: bool = true
var music_volume: float = 0.0  # dB
var sfx_volume: float = 0.0  # dB


func _ready() -> void:
	setup_audio_players()
	Server.music_track_changed.connect(_on_music_track_changed)

func setup_audio_players() -> void:
	"""Create audio players"""
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
		
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "SFX"
	add_child(sfx_player)

func set_music_enabled(enabled: bool) -> void:
	"""Toggle music on/off"""
	music_enabled = enabled
	
	if music_enabled:
		if not current_track.is_empty() and not music_player.playing:
			music_player.play()
	else:
		music_player.stop()
	
	print("Music enabled: ", music_enabled)

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	print("SFX enabled: ", sfx_enabled)

func set_master_sound(enabled: bool) -> void:
	set_music_enabled(enabled)
	set_sfx_enabled(enabled)

func play_track(track_name: String) -> void:
	if not music_tracks.has(track_name):
		push_error("Music track not found: " + track_name)
		return
	
	var track_path: String = music_tracks[track_name]
	
	# Check if file exists
	if not ResourceLoader.exists(track_path):
		push_error("Music file not found: " + track_path)
		return
	
	var stream = load(track_path)
	if not stream:
		push_error("Failed to load music: " + track_path)
		return

	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	
	current_track = track_name
	music_player.stream = stream
	music_player.volume_db = music_volume
	
	if music_enabled:
		music_player.play()

func stop_music() -> void:
	music_player.stop()
	current_track = ""

func play_sfx(sfx_name: String) -> void:
	if not sfx_enabled:
		return

func set_music_volume(db: float) -> void:
	music_volume = clamp(db, -80.0, 0.0)
	music_player.volume_db = music_volume

func set_sfx_volume(db: float) -> void:
	sfx_volume = clamp(db, -80.0, 0.0)
	sfx_player.volume_db = sfx_volume

func _on_music_track_changed(track_name: String) -> void:
	play_track(track_name)

func get_available_tracks() -> Array:
	return music_tracks.keys()

func get_current_track() -> String:
	return current_track
