# 测试文档（张宏伟）

> 记录我对自己模块的验证过程：静态校验 → headless 导入 → 自动自检 → Bug 修复。

## 1. 静态校验

开发中用临时 Python 脚本，对全部 `.tscn/.gd/project.godot` 检查：

- `.tscn` 的 load_steps 与资源引用（ext_resource 路径存在）；
- 节点父链（parent 引用的节点存在）；
- `.gd` 缩进一致性、括号闭合、`class_name` 唯一。

结果：全部通过。

## 2. Godot headless 导入

```
Godot_v4.7.2...exe --headless --path <仓库根> --import
```

结果：全局类 Door / DungeonGenerator / Room 注册成功，无脚本编译错误。

## 3. 自动自检（--selftest）

为保证"本地先做好"，在 test_dungeon.gd 中增加命令行自检模式：

```
Godot_v4.7.2...exe --headless --path <仓库根> -- --selftest
```

自检断言（退出码 0 通过 / 1 失败）：

1. 房间数 = 3；
2. 每房敌人点 ≥ 2、玩家/武器出生点非空；
3. 房间 Z 间距 = 12（0 / 12 / 24）；
4. 清敌后门 `_is_open` 且 `room_cleared` 发出；
5. 模拟玩家进门后 `door_entered(1)` 信号正确。

## 4. Bug 1：GDScript lambda 按值捕获（测试脚本自身问题）

- **现象**：自检断言 `room_cleared=false`，但日志已打"房间1 已清空 → 门打开"；
- **根因**：GDScript 匿名函数按值捕获局部变量，lambda 里改的是副本，外层标志位不变；
- **修复**：改用数组（引用类型）共享状态，`flags[0] = true`；
- **教训**：GDScript 闭包共享状态要用数组 / 成员变量，别用局部布尔。

## 5. Bug 2：next_room_index 时序（真实逻辑 Bug）

- **现象**：`door_entered fired=true next=-1 期望 1`；
- **根因**：生成器在 `add_child(room)` 之前调用 `set_next_room_index`，此时房间 `_ready` 未执行、`_door` 为空引用，索引静默丢失（保留默认 -1）；
- **修复**：先 `add_child(room)` 触发 `_ready` 绑定门，再 `set_next_room_index(i+1)`；
- **教训**：`@onready` 依赖 `_ready` 时序，节点加入场景树前调用会被静默吞掉。

## 6. 最终验证日志（退出码 0）

```
[TestDungeon] Room1 pos=(0.0, 0.0, 0.0) 敌人点=3 武器点=(0.0, 0.5, -1.0) 玩家点=(0.0, 0.5, -3.0)
[TestDungeon] Room2 pos=(0.0, 0.0, 12.0) 敌人点=3 武器点=(0.0, 0.5, 11.0) 玩家点=(0.0, 0.5, 9.0)
[TestDungeon] Room3 pos=(0.0, 0.0, 24.0) 敌人点=3 武器点=(0.0, 0.5, 23.0) 玩家点=(0.0, 0.5, 21.0)
[SelfTest] OK: 3 房间排列与生成点齐全
[TestDungeon] 房间1 已清空 → 门打开
[SelfTest] OK: 清敌后门打开，room_cleared 已发出
[TestDungeon] door_entered → 下一房间 1
[SelfTest] OK: door_entered(1) 信号正常
[SelfTest] === 全部通过 ===
```

## 7. 手动验证（有界面时）

Godot 打开仓库根 → F5：

- 按 T 模拟击杀，看门是否在清敌后隐藏；
- WASD 走入隐藏的门，确认控制台打印"下一房间 1"并传送。
