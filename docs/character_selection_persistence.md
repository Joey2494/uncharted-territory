# 已确认角色的持久化

已确认角色保存在原有 `user://player_profile.cfg` 的 `profile/selected_character` 字段中，由 `player_profile.gd` 与金币、角色所有权一起保存。确认选角成功后立即写入，浏览、取消和单纯解锁不会覆盖选择；金币变化与后续角色购买也会保留该字段及存档中的其他字段。

应用启动时，`Main._enter_tree()` 在玩家进入场景树、创建外观和初始化属性之前读取已确认角色，随后首页、选角页和“继续游戏”使用同一角色。正在进行的显式跨场景角色交接继续优先使用原有 handoff，不被默认值覆盖。

旧存档没有角色选择字段时使用免费 Knight，保留金币和解锁列表；无效 ID、错误类型或未拥有的角色同样回退到 Knight。确认时仍须通过所有权检查。保存失败会保留原选择、显示错误，并允许重新确认。

角色页的 Enter/小键盘 Enter 由当前焦点按钮处理，返回、解锁和确认分别触发自己的动作。打开页面时，已拥有的角色默认聚焦确认；可购买的锁定角色聚焦解锁；金币不足时聚焦返回。禁用或隐藏的确认/解锁按钮会立即释放焦点并退出 Tab 遍历，避免保留金色焦点框。购买成功后焦点回到新启用的确认按钮；购买本身仍不自动确认角色。普通刷新保留当前可用按钮上的焦点，左右切换角色和 Esc 返回沿用原行为。

测试使用独立角色与关卡存档。以下 write 与 resume 命令必须由两个独立引擎进程先后执行，且共享同一用户数据目录，以验证真实的应用重启：

```text
godot --headless --path . --script res://tests/scenes/character_persistence_tests.gd
godot --headless --path . --script res://tests/scenes/character_persistence_tests.gd -- --phase=write
godot --headless --path . --script res://tests/scenes/character_persistence_tests.gd -- --phase=resume
godot --headless --path . --script res://tests/scenes/character_persistence_tests.gd -- --phase=failure
godot --headless --path . --script res://tests/scenes/character_keyboard_tests.gd
```

write 阶段沿用实际解锁与确认入口选择 Lan 并进入第一关，然后结束进程；resume 阶段读取相同测试存档，断言启动时的模型、属性、菜单选择和“继续游戏”中的玩家均为 Lan。另覆盖旧存档、非法与锁定角色、浏览取消、购买和金币更新、保存失败重试，并验证关卡进度保持。

键盘测试使用真实输入事件核对主 Enter/小键盘 Enter 的返回、解锁与确认、按键重复时单次扣费、购买与确认分离、禁用焦点与 Tab 跳过、余额不足、鼠标和左右键切换、Esc 返回及快速重开页面。图形模式添加 `-- --capture` 可保存金币充足与不足时的锁定角色截图。
