# 最近游玩关卡与继续游戏

2026-11-18 测试版规则：全部三个正式关卡均可直接选择，不再根据前一关通关或历史游玩记录设锁。`is_unlocked()` 只检查是否为有效关卡 ID，无效关卡仍被拒绝。以下字段继续记录真实进度；开放关卡不会自动写入通关或游玩记录。

`campaign_progress.gd` 在原有 `user://campaign_progress.cfg` 的 campaign 节点中保存三个字段：

- `completed`：真实通关记录，用于显示完成状态。
- `played`：已实际玩过的关卡列表，保留首次进入顺序。
- `last_played`：最近一次实际开始游玩的关卡，供主页提示与“继续游戏”共同读取。

`Main._on_run_started()` 在实际开局后调用 `mark_played(level_id)`，每次都更新并保存 `last_played`，包括重新进入已玩过的关卡。浏览角色、选关、载入菜单及通关结算不会将其他关卡误记为最近游玩目标。记录更新不改动角色档案和当前角色选择；保存时保留进度文件中的其他字段。

旧存档没有 `last_played` 或该字段无效时，回退到原有 played 列表末项，维持原先可继续的关卡。旧格式没有记录的历史重玩顺序无法反推；下一次实际开局后便会写入独立的最近记录。新存档没有游玩记录时仍禁用“继续游戏”。

同一进程内，规范化后指向同一存档路径的进度实例共享会话状态；不同存档路径互相隔离。只在首次访问时从磁盘初始化，场景重载、返回菜单和跨关卡时继续使用当前会话的通关、已玩、最近关卡及保存失败提示，旧磁盘数据不会覆盖尚未保存的进度。状态本身不引用场景节点，旧场景的进度对象可正常释放。

保存失败只更新提示，不回滚会话进度。之后实际进入关卡或再次通关时照常尝试保存，并写入完整的会话进度；成功后清除共享的失败提示，保留文件内其他字段。存储仍不可写时，本次运行仍保留会话进度，全部关卡也始终开放；退出进程后只能恢复最后一次成功写入磁盘的进度。

回归测试使用独立测试存档。write 与 resume 必须先后由两个独立引擎进程执行，并使用相同的用户数据目录，以模拟关闭应用再启动：

```text
godot --headless --path . --script res://tests/scenes/continue_progress_tests.gd
godot --headless --path . --script res://tests/scenes/continue_progress_tests.gd -- --phase=write
godot --headless --path . --script res://tests/scenes/continue_progress_tests.gd -- --phase=resume
```

write 阶段通过实际选角与选关进入第一关、第二关、再进入第一关；resume 阶段从磁盘恢复后点击“继续游戏”，断言实际进入第一关，并核对第二关解锁、角色所有权、金币及现有角色选择行为。

保存失败的会话回归同样使用独立用户数据目录，`flow` 和 `resume` 先后在两个进程中运行：

```text
godot --headless --path . --script res://tests/scenes/session_unlock_tests.gd
godot --headless --path . --script res://tests/scenes/session_unlock_tests.gd -- --phase=flow
godot --headless --path . --script res://tests/scenes/session_unlock_tests.gd -- --phase=resume
```

默认测试覆盖多实例共享、释放旧实例后恢复、旧磁盘快照、不同路径隔离及恢复写盘后的完整进度。`flow` 将测试进度文件指向不存在的父目录以触发真实写入失败，通过实体出口完成第一关，再从结算返回选关、进入第二关、返回主菜单继续、重载第二关，并验证第二关始终可选可进；恢复测试目录后在真实开局时保存全部进度。`resume` 验证保存恢复后的独立新进程仍可使用 Lan 继续第二关。
