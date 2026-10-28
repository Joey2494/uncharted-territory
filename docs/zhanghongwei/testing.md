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
4. **初始**：所有门关闭，第一个房间后门封死；
5. 清 R1 后：R1 前门开、R2 后门开、`room_cleared` 发出；
6. 模拟玩家进入 R2（有敌人）→ R2 两门关闭（困住）；
7. 清 R2 后两门开、R3 后门开；清 R3 后前门开且 `target=3`（越界=通关）；
8. 门按行进方向触发：前门只在前进时触发、后门只在后退时触发（各一次）。

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

## 6. Bug 3：玩家从首房后门跑出地图（实跑发现）

- **现象**：从第一个房间最上方的门直接跑出地图；
- **根因**：后墙 `WallZBackL/R` 中间留了门洞，但门洞处没有任何门节点；
- **修复**：每个房间加 `BackDoor`，第一个房间的 `BackDoor` 调 `seal()` 永久封死。

## 7. Bug 4：门不阻挡、门板是白色（实跑发现）

- **现象**：各房间门一开始畅通无阻，门板是白色而非设计的红色；
- **根因**：
  - 门是 `Area3D`，碰撞形状只用于检测、**不产生物理阻挡**；
  - 地板/墙/门板的 `StandardMaterial3D` 定义了却**没被 Mesh 引用**，全部用默认白色材质；
- **修复**：
  - 门内加 `Blocker`（StaticBody3D + 碰撞），关门阻挡、开门禁用碰撞；
  - 给所有 BoxMesh 补 `material = SubResource(...)` 引用（门板恢复红色）。

## 8. Bug 5：进入下一房间后无法返回（实跑发现）

- **现象**：清敌进下一房间后回不去原房间；
- **根因**：每个房间只有一个前门，没有后门；
- **修复**：加 `BackDoor` + `RoomArea`，玩家进入有敌人房间自动关门、清敌自动开门，已探索房间可往返；门按进入侧判定方向，避免重复触发。

## 9. 最终验证日志（退出码 0）

```
[TestDungeon] Room1 pos=(0.0, 0.0, 0.0) 敌人点=3 武器点=(0.0, 0.5, -1.0) 玩家点=(0.0, 0.5, -3.0)
[TestDungeon] Room2 pos=(0.0, 0.0, 12.0) 敌人点=3 武器点=(0.0, 0.5, 11.0) 玩家点=(0.0, 0.5, 9.0)
[TestDungeon] Room3 pos=(0.0, 0.0, 24.0) 敌人点=3 武器点=(0.0, 0.5, 23.0) 玩家点=(0.0, 0.5, 21.0)
[SelfTest] OK: 3 房间排列与生成点齐全
[SelfTest] OK: 初始门关闭，R1 入口封死
[TestDungeon] 房间1 已清空 → 门打开
[SelfTest] OK: 清 R1 后前门开、R2 后门开
[SelfTest] OK: 进入 R2 后两门关闭（困住）
[TestDungeon] 房间2 已清空 → 门打开
[SelfTest] OK: 清 R2 后两门开、R3 后门开
[TestDungeon] 房间3 已清空 → 门打开
[SelfTest] OK: 清 R3 后前门开（出口）
[TestDungeon] door_entered → 房间 1
[TestDungeon] door_entered → 房间 0
[SelfTest] OK: 门按行进方向触发（前进/后退各一次）
[SelfTest] === 全部通过 ===
```

## 10. 手动验证（有界面时）

Godot 打开仓库根 → F5：

- 初始：首房后门是红色门板且撞不出去，前门也撞不出去；
- 按 T 清敌后，两门打开，WASD 自然走入下一房间；
- 进入有敌人的房间时两门自动关闭（被困住）；
- 清敌后两门重开，可走回已探索房间、也可再前进。
