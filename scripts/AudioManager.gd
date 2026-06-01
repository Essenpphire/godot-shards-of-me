extends Node

#建立枚举对应各个管线
enum Bus{
	MASTER,
	SFX,
	MUSIC,
}
const SFX_BUS="SFX"
const MUSIC_BUS="Music"

#音乐播放器配置
#音乐播放器数量
var music_audio_player_count:=2
#当前播放音乐的播放器序号，默认是0
var current_music_player_index:=0
#音乐播放器存放的数组，方便调用
var music_players:Array[AudioStreamPlayer]
#音乐渐入渐出时长
var music_fade_duration:float=0.5

#音效播放器配置
#音效播放器数量
var sfx_audio_player_count:=6
#当前播放音效的播放器序号，默认是0
var current_sfx_player_index:=0
#音效播放器存放的数组，方便调用
var sfx_players:Array[AudioStreamPlayer]

func _ready() -> void:
	_init_music_audio_manager()
	_init_sfx_audio_manager()

#初始化音乐播放器
func _init_music_audio_manager()->void:
	for i in music_audio_player_count:
		var audio_player:=AudioStreamPlayer.new()
		audio_player.process_mode=Node.PROCESS_MODE_ALWAYS
		audio_player.bus=MUSIC_BUS
		add_child(audio_player)
		music_players.append(audio_player)

## 音乐停止
func stop_music() -> void:
	var current_audio_player:=music_players[current_music_player_index]
	_fade_out_and_stop(current_audio_player)
		
## 音乐播放
func play_music(_audio: AudioStream) -> void:
	var current_player := music_players[current_music_player_index]
	var current_stream := current_player.stream
	
	# 检查是否需要切换
	var need_switch = true
	
	if current_stream != null:
		if current_stream == _audio or current_stream.resource_path == _audio.resource_path:
			print("同一首歌，继续播放")
			return  # 相同，什么都不做
		else:
			# 不同歌曲，渐出当前
			print("切换歌曲: ", _audio.resource_path.get_file())
			_fade_out_and_stop(current_player)
	else:
		# 当前没有播放，直接播放新歌
		print("首次播放: ", _audio.resource_path.get_file())
	
	# 切换到新播放器播放
	var next_index = 0 if current_music_player_index == 1 else 1
	var next_player := music_players[next_index]
	
	next_player.stream = _audio
	_play_and_fade_in(next_player)
	current_music_player_index = next_index
	
#音乐淡入
func _play_and_fade_in(_audio_player:AudioStreamPlayer)->void:
	#_audio_player.volume_db = -10.0
	_audio_player.play()
	var tween:Tween=create_tween()
	tween.tween_property(_audio_player,"volume_db",0,music_fade_duration)
#音乐淡出
func _fade_out_and_stop(_audio_player:AudioStreamPlayer)->void:
	var tween:Tween=create_tween()
	tween.tween_property(_audio_player,"volume_db",-40,music_fade_duration)
	await tween.finished
	_audio_player.stop()
	_audio_player.stream=null
	
#初始化音效播放器
func _init_sfx_audio_manager()->void:
	for i in sfx_audio_player_count:
		var audio_player:=AudioStreamPlayer.new()
		audio_player.bus=SFX_BUS
		add_child(audio_player)
		sfx_players.append(audio_player)
## 音效播放
func play_sfx(_audio:AudioStream,_is_random_pitch:bool=false)->void:
	var pitch:=1
	if(_is_random_pitch):
		pitch=randf_range(0.9,1.1)
	for i in sfx_audio_player_count:
		var sfx_audio_player:=sfx_players[i]
		if not sfx_audio_player.playing:
			sfx_audio_player.stream=_audio
			sfx_audio_player.pitch_scale=pitch
			sfx_audio_player.play()
			return
	print("当前音效节点已满")
## 设置各个管线的音量 [br]
## [b]注意v的范围：0.0 ~ 1.0![/b]
func set_volume(bus_index:Bus,v:float)->void:
	var db:=linear_to_db(v)
	AudioServer.set_bus_volume_db(bus_index,db)
