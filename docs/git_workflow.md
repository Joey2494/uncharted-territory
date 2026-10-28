# Git 协作流程（全组）

> 维护人：张宏伟（仓库 / 目录管理）
> 目的：每人独立开发互不干扰，测试场景不影响他人，main 始终保持可运行。

## 一、分支模型

| 分支 | 用途 | 谁能改 |
|---|---|---|
| `main` | 稳定、可运行版本；**只通过 PR 合并**，不直接提交 | 仅合并 |
| `feature/<模块名>` | 每人的开发分支 | 分支所有者 |

每人的功能分支（从最新 `main` 建）：

| 成员 | 分支名 | 模块 |
|---|---|---|
| 张宏伟 | `feature/dungeon-door-fix` | 地牢 / 房间 / 门 |
| 俞吉依 | `feature/player` | 玩家 / 整合 |
| 字远 | `feature/enemies` | 敌人 / 道具 |
| 汤志豪 | `feature/ui` | UI / 视觉音效 |

## 二、标准开发流程（每人照做）

```powershell
# 1. 先同步最新 main
git checkout main
git pull origin main

# 2. 从 main 建自己的功能分支
git checkout -b feature/xxx

# 3. 开发，小步提交（每完成一个可验证功能就提交）
git add <文件>
git commit -m "feat: 简述"

# 4. 推送自己的分支
git push -u origin feature/xxx

# 5. GitHub 上发 Pull Request（base: main ← compare: feature/xxx），通知审查
# 6. 合并后，本地同步
git checkout main
git pull origin main
```

## 三、测试场景不会影响其他人

当前 `project.godot` 的主场景临时指向**张宏伟的测试场景** `scenes/dungeon/test_dungeon.tscn`，按以下规则就互不干扰：

- **测自己的场景**：在编辑器里打开自己的 `.tscn`，按 **F6（运行当前场景）**，不依赖 F5；
- F5 永远运行"主场景"，整合前是测试场景，整合后是正式入口；
- 测试场景 / 测试玩家（`test_dungeon`、`test_player`）是**开发专用**，不被其他模块引用，可保留作回归测试；
- 俞吉依建好 `scenes/main.tscn` 后，把 `project.godot` 的主场景改为 `res://scenes/main.tscn`（仅他改这一处）。

## 四、共享文件（冲突高发，需协调）

| 文件 | 规则 |
|---|---|
| `project.godot` | 主场景、输入映射；整合阶段由俞吉依统一改，其他人需要输入动作先在群里说 |
| `scenes/main.tscn` | 俞吉依独占 |
| `scenes/dungeon/room_template_*.tscn` | **不要把敌人 / 道具烤进模板**，运行时按 Marker 生成（`EnemySpawnPoint` 等） |
| 自己目录下的文件 | 自己随便改，互不冲突 |

## 五、冲突处理

- 各模块在独立目录（`scenes/player`、`enemies`、`ui`、`dungeon`），**文件级冲突极少**；
- 合并前先 `git pull origin main` 把最新代码并进来；
- 若 `project.godot` 冲突，不要硬删，找张宏伟 / 俞吉依一起核对；
- 小步、勤合并，避免长期不合并导致大冲突。
