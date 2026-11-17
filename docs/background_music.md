# 背景音乐

`MusicManager` 是自动加载的常驻节点，仅持有一个 `AudioStreamPlayer`，输出到 `Music` 总线。音效继续使用原来的播放节点与 Master 总线。

在 `scenes/audio/default_music_playlist.tres` 中分别指定主菜单 `menu`、第一关 `level_1`、第二关 `level_2`、胜利结算 `victory` 的 AudioStream。两关正式游玩使用 `assets/audio/bgm/2. The Hidden Grove.wav`；主菜单、角色选择、关卡选择及胜利结算保留 `assets/audio/bgm/the-hall-of-the-kingdom-ii_8702604f.mp3`。可在 Inspector 中逐项替换，无需改动关卡代码。

主菜单及选角、选关、设置页面使用菜单音乐；实际开始关卡时切换为对应关卡音乐，确认通关并进入结算时切换为胜利音乐，返回菜单时恢复菜单配置。暂停、商店、背包、操作指南及死亡结算保留当前曲目。

重复请求或不同场景共用同一曲目时，播放器保持当前进度，不重播、不叠加。不同曲目先淡出再淡入；快速连续切场景会取消过时的切换。MP3、OGG、WAV 使用运行时副本开启循环，原始音乐和音效导入设置保持不变。

设置页的“背景音乐”仅调整 Music 总线，“主音量”仍控制全部声音。音乐静音时播放进度继续，恢复音量不会重头播放。音量写入原有 `user://settings.cfg`，旧设置文件缺少音乐音量时采用 65%。

可从项目目录运行 `godot --headless --path . --script res://tests/audio/test_background_music.gd`。测试使用独立档案，并覆盖音轨循环与切换、暂停、旧设置兼容、音量保存、音效触发、两关实体出口、返回菜单和四种窗口尺寸。

正式关卡音乐的基础增益为 -4 dB，菜单与结算音乐保留 -8 dB，不重写玩家保存的总音量或音乐音量。增益跟随实际播放曲目，切歌淡出期间保留旧曲音量。

音乐管理器保留可选的 `set_ambience_duck(owner, enabled)` 混音接口：有效且正在处理的请求可让音乐降低 5 dB，请求结束、暂停或释放后恢复。该接口与切歌淡入淡出独立，多个请求不会互相取消。本分支不创建环境音调度器，也不迁移蛛鸣、第二关门音扩展或 Boss 死亡音效；团队原有 `game_sfx.gd` 与音效素材保持基准内容。

`tests/audio/test_gameplay_music_mix.gd` 验证真实主菜单→选角→选关→开局、指定 WAV 的原生循环、同曲跨关连续播放、过期切歌取消，并用无音效测试节点验证音乐混音接口、暂停恢复与请求释放。全程只保留一个背景音乐播放器。
