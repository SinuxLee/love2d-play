# ML 个性化难度适应系统 - 技术设计文档

> Match-3 三消游戏 | 纯 Lua/Love2D 实现 | 无外部依赖

---

## 1. 背景与目标

### 现状问题

当前的动态难度调整 (DDA) 系统基于 3 条固定数学曲线，根据**连败次数**线性调整掉落偏置 (dropBias)：

```
linear(n)      = 0.05 × n          （每败一次 +0.05）
quadratic(n)   = 0.015 × n²        （加速增长）
logarithmic(n) = 0.12 × ln(n + 1)  （递减增长）
```

**核心缺陷**：
- 所有玩家共享同一套参数——休闲玩家和高手在同一关获得相同帮助
- 系统只响应"失败"信号，不学习玩家的实际能力维度（效率、连击、策略）
- 无跨关记忆——过关后连败计数器归零，失去已积累的玩家认知

### 设计目标

用数据驱动的自适应系统替代固定曲线，实现**千人千面**：

1. **个性化难度**：每个玩家获得匹配其能力的难度体验
2. **心流优化**：系统学习让玩家停留在"不太难也不太简单"的心流区间
3. **智能提示**：根据玩家水平给出不同强度的提示
4. **商业化衔接**：难度适配自然产生精准的付费推荐时机

### 技术约束

| 约束 | 原因 |
|------|------|
| 纯 Lua 实现 | Love2D 运行时，无 C 扩展 / FFI |
| 无服务器依赖 | 单机游戏，离线运行 |
| 零帧内开销 | 60fps 目标不可妥协 |
| 代码量 < 600 行 | 保持项目轻量可维护 |

---

## 2. 系统架构总览

```
                    关卡结束
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
   PlayerProfile   SkillEstimator  Reward
   (EMA 画像更新)   (Elo 式评分)   (心流奖励)
         │             │             │
         └──────┬──────┘             │
                ▼                    ▼
          DifficultyBandit ◄── updateArm(reward)
          (Thompson Sampling)
                │
                ▼  关卡开始时
          selectArm(profile)
                │
                ▼
          Grid.dropBias ──► smartDrop() ──► 新宝石生成
```

**关键特性**：ML 系统只改变 `Grid.dropBias` 的来源，不修改游戏核心逻辑（smartDrop 算法不变），实现零侵入式集成。

---

## 3. 玩家画像系统

### 3.1 追踪特征

每次通关/失败时，从已有的游戏状态数据中提取 6 个归一化特征：

| 特征 | 数据来源 | 含义 |
|------|---------|------|
| `scoreEfficiency` | score / targetScore | 得分能力（1.0 = 恰好达标） |
| `moveEfficiency` | movesUsed / maxMoves | 步数效率（低 = 更强） |
| `comboSkill` | maxCombo / 5 | 连击意识（5 连击 = 满分） |
| `specialSkill` | specialsCreated / 4 | 特殊宝石运用能力 |
| `passRate` | 通关=1 / 失败=0 | 通关率 |
| `frustration` | 失败 +0.15，通关 ×0.6 | 挫败感指数（快升慢降） |

所有特征使用 **EMA（指数移动平均）** 更新，alpha = 0.15，相当于 ~7 次尝试的滑动窗口，既能快速响应能力变化，又不会因单次波动剧烈抖动。

### 3.2 综合技能分

```
skillScore = 0.30 × scoreEfficiency
           + 0.25 × (1 - moveEfficiency)
           + 0.20 × comboSkill
           + 0.15 × specialSkill
           + 0.10 × passRate
```

### 3.3 玩家分型

| 类型 | skillScore 区间 | 系统行为 |
|------|---------------|---------|
| Casual | 0.00 - 0.30 | 较强辅助 + 最优提示 + 5 秒超时提示 |
| Normal | 0.30 - 0.55 | 标准难度 + 中等提示 + 10 秒超时 |
| Hardcore | 0.55 - 0.80 | 适度挑战 + 弱提示 + 20 秒超时 |
| Expert | 0.80 - 1.00 | 高难度 + 最弱提示 + 30 秒超时 |

分型是连续画像的离散化展示，不影响底层算法——底层始终使用连续 skillScore。

---

## 4. Thompson Sampling 自适应难度

### 4.1 核心思路

将 dropBias 选择建模为**多臂老虎机 (Multi-Armed Bandit)** 问题：

- 7 个离散 bias 档位作为"臂"（-0.30 到 +0.45）
- 每个臂维护一个 Beta(alpha, beta) 概率分布
- 每次开始关卡时，从每个臂的分布中采样，选择采样值最高的臂

Thompson Sampling 的优势：自动平衡**探索**（尝试不确定的 bias 值）与**利用**（使用已知好的 bias 值），无需手动调参。

### 4.2 七个 Bias 档位

| 档位 | Bias 值 | 效果描述 |
|-----|---------|---------|
| 0 | -0.30 | 极具挑战（减少有利掉落） |
| 1 | -0.15 | 中等挑战 |
| 2 | -0.05 | 略有挑战 |
| 3 | +0.00 | 中性（纯随机） |
| 4 | +0.10 | 轻度辅助 |
| 5 | +0.25 | 中度辅助（增加有利掉落） |
| 6 | +0.45 | 强力辅助 |

### 4.3 奖励函数（核心设计）

**奖励不是"玩家是否赢了"，而是"玩家是否处于心流状态"。**

```lua
-- 钟形曲线：峰值在 scoreRatio = 1.05（刚好通关时最高奖励）
flowReward = exp(-((scoreRatio - 1.05)^2) / (2 * 0.3^2))

-- 反挫败惩罚：得分低于目标 60% 时惩罚
frustPenalty = scoreRatio < 0.6 ? (0.6 - scoreRatio) * 0.5 : 0

-- 连击兴奋感加成
comboBonus = min(0.15, maxCombo * 0.03)

reward = clamp(0, 1, flowReward - frustPenalty + comboBonus)
```

**设计意图**：
- 轻松碾压 (scoreRatio >> 1.0) 的奖励不如紧张通关 (≈ 1.05) 高
- 彻底碾压式的失败 (< 0.6) 受罚，防止系统让玩家绝望
- 大连击本身就是乐趣，无论输赢都给予正向反馈

### 4.4 非平稳性处理

玩家能力会随时间变化。每次更新时，所有臂的 alpha/beta 乘以衰减因子 0.95，让旧观测逐渐失效。效果：约 20 关后旧数据权重降至 36%，系统能跟上玩家的成长节奏。

### 4.5 安全机制

- **画像先验注入**：高挫败玩家采样时偏向辅助臂；高技能玩家偏向挑战臂
- **挫败安全阀**：frustration > 0.8 时，强制最低 bias = +0.10，防止流失
- **Legacy 回退**：完整保留旧 DDA 系统，GM 面板一键切换

---

## 5. 贝叶斯技能估计器

维护玩家"真实技能等级"的概率估计，类似 Elo 评分系统：

```
expected = 1 / (1 + exp(-(mu - levelNum) / sigma))
surprise = outcome - expected
mu = mu + K × surprise       (K = sigma × 0.3)
sigma: 符合预期 → 缩小（更确定），出乎意料 → 扩大（重新探索）
```

用途：判断当前关卡对该玩家是"偏简单"还是"偏困难"，为 Bandit 的先验注入提供依据。

---

## 6. 技能自适应提示系统

### 提示强度随技能调整

| 玩家类型 | 使用 AI 策略 | 理由 |
|---------|------------|------|
| Casual | MonteCarlo（最优解） | 需要真正的帮助来继续游戏 |
| Normal | Heuristic（较优解） | 指引方向但不代劳 |
| Hardcore/Expert | Greedy（一般解） | 仅帮助解除卡顿，不破坏乐趣 |

提示仅高亮建议位置（不自动执行），玩家可选择忽略。

### 目标感知

提示评分时考虑当前关卡目标——如果目标是"收集红宝石 20 颗"，优先推荐能消除红宝石的交换。

---

## 7. 数据持久化

所有 ML 状态通过现有 Save 系统持久化，新增字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `profile` | table | 6 个 EMA 特征值 + skillScore + archetype |
| `banditArms` | table | 7 个臂的 {alpha, beta} |
| `skillMu` | number | 技能估计均值 |
| `skillSigma` | number | 技能估计不确定度 |

总序列化大小 < 1KB，旧存档加载时自动填充默认值（向后兼容）。

---

## 8. 工程可行性分析

### 算法复杂度

| 组件 | 时间复杂度 | 执行频率 | 实际耗时 |
|------|-----------|---------|---------|
| EMA 画像更新 | O(1) | 每关结束 1 次 | < 0.01ms |
| Thompson Sampling | O(7 × ~3 迭代) | 每关开始 1 次 | < 0.05ms |
| 贝叶斯 Elo 更新 | O(1) | 每关结束 1 次 | < 0.01ms |
| 奖励计算 | O(1) | 每关结束 1 次 | < 0.01ms |
| **帧内额外开销** | **O(0)** | **每帧** | **0ms** |

Beta 采样使用 Joehnk 算法，仅依赖 `math.random()`，在 alpha/beta >= 1 时平均 2-3 次循环收敛。

### 代码量估算

| 模块 | 新增行数 | 修改行数 | 复杂度 |
|------|---------|---------|-------|
| `systems/profile.lua` | ~180 | — | 简单（含 avgMoveTime + 快速校准 + 反摆烂） |
| `systems/bandit.lua` | ~220 | — | 中等（含分桶上下文 + 自适应奖励 + fallback） |
| `systems/hints.lua` | ~80 | — | 简单（复用已有 autoplay） |
| `systems/save.lua` | — | ~15 | 简单（加字段 + 默认值） |
| `systems/states.lua` | — | ~40 | 中等（管道集成 + 决策日志） |
| `ui/gm.lua` | — | ~60 | 简单（ML 调试视图） |
| `tools/benchmark.lua` | — | ~200 | 中等（100 合成玩家含行为动态 + 指标 + t-test） |
| 单元测试 | ~200 | — | 简单 |
| **合计** | **~680** | **~315** | — |

核心 ML 逻辑（profile + bandit）**约 400 行纯 Lua**（含分桶上下文、快速校准、自适应奖励、反摆烂、fallback），无外部依赖，可独立单元测试。决策日志和评估框架约 250 行额外代码。

### 工程风险与缓解

| 风险 | 严重度 | 缓解措施 |
|------|-------|---------|
| Beta 采样精度 | 低 | Joehnk 算法有成熟数学理论支撑，alpha/beta >= 1 时精确 |
| 冷启动体验 | 中 | 前 10 关用均匀先验，效果等同当前无 DDA，无退步风险 |
| 参数调优 | 中 | 奖励函数参数可通过 GM 面板实时调整，benchmark 批量验证 |
| 旧存档兼容 | 低 | 所有新字段有默认值，旧存档无缝升级 |
| 与现有系统冲突 | 低 | Legacy DDA 完整保留，一键切换模式 |

### 架构兼容性

- **零侵入**：smartDrop() 不需任何改动，ML 只改变 dropBias 来源
- **复用 Logger**：所有 ML 决策记入现有 JSON Lines 日志
- **复用 Save**：现有序列化器已支持嵌套 table/number
- **复用 GM 面板**：已有折叠区框架，新增一个 section 即可

---

## 9. 实现计划

### 阶段划分

| 阶段 | 内容 | 止损点 |
|------|------|-------|
| Phase 1 | profile.lua（含 avgMoveTime + 快速校准）+ bandit.lua（含分桶上下文 + 自适应奖励 + 反摆烂 + fallback）+ 单元测试 | 核心算法可独立验证 |
| Phase 2 | save.lua + states.lua 集成 | ML 难度调整可玩；如 benchmark Flow Index 提升 < 5pp → 停止 |
| Phase 3 | 决策日志 + 可解释性 + GM 面板 ML 视图（含可调权重） | 每步决策可追踪可解释 |
| Phase 4 | hints.lua 提示系统 | 技能自适应提示 |
| Phase 5 | benchmark 评估框架（100 合成玩家含行为动态 + 对比指标 + t-test） | 数据证明效果；如无显著差异 → 回退 legacy |

### 验证标准

1. 单元测试通过（Beta 采样分布正确、EMA 收敛、Elo 更新方向正确、反摆烂阈值正确）
2. 快速校准：3 关后高手/新手获得不同的 Bandit 先验（非均匀）
3. 分桶 Bandit：不同修饰器组合的关卡使用独立的臂状态
4. 日志中每次 ML 决策都有完整 `ml_select`/`ml_update` 事件，含奖励分项和臂状态
5. GM 面板实时展示 skillScore、臂状态、决策解释文本、可调权重
6. Benchmark 评估报告：ML-DDA Flow Index > 60%，且 p < 0.05（显著优于 legacy）
7. Fallback 机制：bias 最高臂 + 连败 3 次后触发降目标/加步数
8. 存档向后兼容（旧存档加载无报错）

---

## 10. 决策可追踪性与可解释性

### 10.1 结构化决策日志

每次 ML 做出决策时，Logger 记录完整的因果链（非只记结果）：

**关卡开始 — `ml_select` 事件**：
```json
{
  "msg": "ml_select",
  "data": {
    "level": 23,
    "profile": {
      "skillScore": 0.52, "archetype": "normal",
      "scoreEff": 0.93, "moveEff": 0.72, "comboSkill": 0.64,
      "specialSkill": 0.38, "passRate": 0.71, "frustration": 0.22
    },
    "skill_estimate": {"mu": 20.3, "sigma": 4.1},
    "samples": [0.31, 0.45, 0.52, 0.61, 0.58, 0.43, 0.29],
    "arms": [
      {"bias": -0.30, "alpha": 3.1, "beta": 8.2},
      {"bias": -0.15, "alpha": 5.4, "beta": 6.1},
      ...
    ],
    "selected_arm": 3,
    "selected_bias": 0.00,
    "prior_adjustments": "none",
    "safety_valve": false,
    "final_bias": 0.00,
    "reason": "arm#3 had highest sample (0.61); no overrides"
  }
}
```

**关卡结束 — `ml_update` 事件**：
```json
{
  "msg": "ml_update",
  "data": {
    "level": 23, "passed": true,
    "score_ratio": 1.08,
    "reward_breakdown": {
      "flow_reward": 0.99, "frust_penalty": 0.00,
      "combo_bonus": 0.09, "final_reward": 1.00
    },
    "arm_before": {"alpha": 7.2, "beta": 4.8},
    "arm_after": {"alpha": 7.84, "beta": 4.56},
    "profile_before": {"skillScore": 0.52},
    "profile_after": {"skillScore": 0.53},
    "skill_before": {"mu": 20.3, "sigma": 4.1},
    "skill_after": {"mu": 21.1, "sigma": 4.0}
  }
}
```

### 10.2 人类可读解释

每次决策同时生成一行自然语言摘要，显示在 GM 面板并写入日志：

```
"Normal 玩家 (skill=0.52), 近期稳定偏好中性难度, 给予 bias=0.00 (Arm#3, 采样值0.61最高)"
"刚失败 3 次, frustration=0.45, 系统开始偏向辅助臂"
"Expert 玩家连过 5 关, 系统探索挑战性更强的 bias=-0.15"
```

模板规则（~20 行 Lua）：
- frustration > 0.5 → "玩家受挫, 偏向辅助"
- 连续选同一臂 ≥ 3 次 → "系统稳定在 bias=X"
- 切换到不同臂 → "系统探索 bias=X"
- safety valve 触发 → "安全阀生效, 强制最低辅助"

### 10.3 GM 面板 ML 调试视图

| 区域 | 展示内容 |
|------|---------|
| 画像概览 | `Normal skill=0.52 frust=0.22` 一行摘要 |
| 臂状态 | 7 个臂的 alpha/beta + 上次采样值，当前选中臂高亮 |
| Elo 估计 | `Skill Lv: 20.3 ± 4.1` |
| 决策解释 | 最近一次自然语言摘要 |
| 趋势指示 | skillScore 5 关内变化方向 (↑/↓/→) |

所有数值实时更新，策划/QA 打开 F1 面板即可看到系统"在想什么"。

### 10.4 离线日志分析

日志为标准 JSON Lines 格式，可直接用任何工具分析：

```bash
# 查看所有 ML 决策
grep "ml_select\|ml_update" logs/game.log | jq .

# 统计各臂被选中的频率
grep "ml_select" logs/game.log | jq '.data.selected_arm' | sort | uniq -c

# 追踪 skillScore 演化
grep "ml_update" logs/game.log | jq '[.data.level, .data.profile_after.skillScore]'

# 查看安全阀触发次数
grep "ml_select" logs/game.log | jq 'select(.data.safety_valve == true)'
```

---

## 11. 效果评估框架

### 11.1 评估方法论

**核心问题**：ML-DDA 比固定曲线好在哪里？好多少？

评估采用 **控制变量对比实验**——在相同的关卡序列和相同的 AI 策略下，比较 legacy DDA 与 ML DDA 的表现差异。

### 11.2 参数化合成玩家模型

真实玩家的行为不是固定策略，而是连续光谱上的一个点，且会随时间变化。

#### 核心思路：4 维参数空间 → 100 种玩家

不再将玩家绑定到某个固定策略，而是用 4 个连续参数描述行为特征：

```lua
---@class SyntheticPlayer
---@field skill number      -- 0.0-1.0  决策质量（控制策略混合）
---@field noise number      -- 0.0-0.5  随机走子概率（注意力/手滑）
---@field growth number     -- 0.0-0.01 每关 skill 增量（学习速度）
---@field volatility number -- 0.0-0.3  每关 skill 随机波动（状态不稳定性）
```

#### 走子决策流程

```
每步走子时：
  1. effectiveSkill = clamp(0, 1, skill + random(-volatility, +volatility))
  2. if random() < noise → 从所有合法交换中随机选一个（模拟失误）
  3. else → 根据 effectiveSkill 混合策略：
       skill < 0.33 → greedy（只看眼前匹配数）
       skill 0.33-0.66 → heuristic（考虑连锁和棋盘势）
       skill > 0.66 → montecarlo（多次模拟取最优）
  4. 关卡结束后：skill += growth（缓慢成长）
```

现有 3 种策略（greedy/heuristic/montecarlo）直接复用，不需要新增策略代码。

#### 100 种玩家的生成

从参数空间中系统采样，覆盖各种典型和极端情况：

**预设模板（20 种）** — 手工设定的典型画像：

| # | 名称 | skill | noise | growth | volatility | 代表人群 |
|---|------|-------|-------|--------|-----------|---------|
| 1 | 纯新手 | 0.05 | 0.40 | 0.000 | 0.05 | 完全没玩过三消的人 |
| 2 | 休闲老手 | 0.25 | 0.20 | 0.000 | 0.10 | 玩过但不求精进 |
| 3 | 认真学习者 | 0.15 | 0.25 | 0.008 | 0.10 | 新手但在快速进步 |
| 4 | 稳定中等 | 0.45 | 0.10 | 0.001 | 0.05 | 大部分普通玩家 |
| 5 | 状态波动型 | 0.40 | 0.15 | 0.002 | 0.25 | 通勤时玩，注意力不稳定 |
| 6 | 高手低噪 | 0.80 | 0.05 | 0.001 | 0.03 | 专注型核心玩家 |
| 7 | 高手高波 | 0.75 | 0.05 | 0.000 | 0.20 | 老手但时好时坏 |
| 8 | 快速成长 | 0.10 | 0.30 | 0.010 | 0.10 | 新手但天赋高 |
| 9 | 摆烂型 | 0.30 | 0.45 | 0.000 | 0.05 | 随便点点打发时间 |
| 10 | 完美主义者 | 0.90 | 0.02 | 0.001 | 0.02 | 每步都深思熟虑 |
| ... | ... | ... | ... | ... | ... | ... |

**网格采样（80 种）** — 参数空间均匀覆盖：

```lua
-- 4 维各取若干值，组合后随机抽取 80 种
local skills     = {0.10, 0.25, 0.40, 0.55, 0.70, 0.85}  -- 6 值
local noises     = {0.05, 0.15, 0.25, 0.35}                -- 4 值
local growths    = {0.000, 0.003, 0.007}                    -- 3 值
local volatils   = {0.05, 0.15, 0.25}                       -- 3 值
-- 全组合 = 6×4×3×3 = 216 种，从中用确定性种子抽取 80 种
```

总计 100 种玩家，用确定性种子生成（可复现）。

#### 为什么这比 4 种固定策略好

| 维度 | 旧方案（4 种） | 新方案（100 种） |
|------|--------------|----------------|
| 技能分布 | 3 个离散点 | 0.05-0.90 连续覆盖 |
| 失误模拟 | 无 | noise 0.02-0.45 |
| 成长模拟 | 硬切换（greedy→heuristic） | 平滑增长 |
| 波动模拟 | 无 | volatility 0.02-0.25 |
| 统计显著性 | N=4，无法做 t-test | N=100，可做分层分析 |

每种合成玩家在**同一随机种子**下分别跑 legacy DDA（3 条曲线）和 ML DDA，确保对比公平。

### 11.3 核心评估指标

| 指标 | 定义 | 目标值 | 含义 |
|------|------|-------|------|
| **Flow Index** | scoreRatio 落在 [0.8, 1.2] 的关卡占比 | > 60% | 玩家大部分时间处于心流区间 |
| **Pass Rate** | 通关率 | 45-65% | 不太容易也不太难 |
| **Frustration Events** | 连败 ≥ 3 次的发生频率 | < 15% | 避免连续挫败 |
| **Adaptation Speed** | Growing Player 切换策略后，系统调整到新均衡所需关卡数 | < 10 关 | 系统能快速跟上能力变化 |
| **Bias Stability** | 连续 10 关内 selected_arm 的标准差 | < 1.5 | 系统不会剧烈抖动 |
| **Score Variance** | scoreRatio 的标准差 | < 0.25 | 体验一致性 |

### 11.4 Benchmark 对比报告

Benchmark 输出分层汇总表——按玩家类型分组对比：

```
=== ML-DDA Evaluation Report (100 Synthetic Players × 100 Levels) ===

Player Group         N    DDA Mode       Flow%   Pass%   Frust%  Score-σ
───────────────────────────────────────────────────────────────────────
Low skill (0-0.3)    28   legacy/best    42.1%   78.3%   22.1%   0.41
                          ML-DDA         61.7%   56.2%    8.3%   0.22  ✓
Mid skill (0.3-0.6)  38   legacy/best    49.8%   71.5%   16.4%   0.35
                          ML-DDA         65.3%   58.1%    7.1%   0.19  ✓
High skill (0.6-1.0) 34   legacy/best    54.2%   65.1%   12.8%   0.31
                          ML-DDA         63.8%   54.3%    6.5%   0.20  ✓

Growing players (growth > 0.005):
  Adaptation speed:  ML avg 6.8 levels to re-converge after skill shift

Overall (N=100):
  Flow Index:  ML 63.4% ± 1.8%  vs  best legacy 49.2% ± 2.1%
  Δ = +14.2 pp, p < 0.001 (Welch's t-test)
```

`legacy/best` 指同组玩家在 linear/quadratic/logarithmic 三条曲线中取最好指标的那条。

### 11.5 统计显著性

100 种玩家 × 每种在**同一种子**下跑 legacy 和 ML-DDA，自然构成**配对样本**。使用配对 t-test：

```lua
-- 配对 t-test: 每个玩家 i 计算 Δi = ML_flow[i] - legacy_flow[i]
-- t = mean(Δ) / (std(Δ) / sqrt(N))
-- N=100, df=99, 查表 t_0.025 ≈ 1.984
```

实现约 20 行 Lua（mean、std、t 值、自由度），无需外部库。

配对设计的优势：消除了"不同玩家本身技能差异"的干扰，只测量"同一玩家用不同 DDA 的效果差"。

### 11.6 实现要点

**新增到 `tools/benchmark.lua`**：
- `SyntheticPlayer` 类：4 维参数 + `pickMove()` 方法（策略混合 + noise + volatility）
- `generatePlayers(n, seed)` 函数：20 预设 + 80 网格采样，确定性可复现
- `simulateLevelML()` 函数：同 `simulateLevel()` 但用 Bandit 选 bias 并在结束时更新
- 指标计算：Flow Index / Frustration Events / Adaptation Speed / Score Variance
- 分层汇总报告 + 配对 t-test

**代码量增加**：约 200 行（合成玩家 ~60 行 + 指标计算 ~50 行 + 报告 ~50 行 + t-test ~20 行 + 生成器 ~20 行）

**复用现有代码**：
- `collectValidSwaps()` — 枚举合法交换（autoplay.lua:553）
- `evaluateSwap()` — greedy 评估（autoplay.lua:281）
- `strategies.heuristic` / `strategies.montecarlo` — 现有策略直接调用
- `simulateLevel()` / `headlessCascade()` — 现有仿真引擎

### 11.7 持续验证

ML 系统上线后，通过已有 Logger 持续收集数据：
- 每个真实玩家的 scoreRatio 分布 → 验证 Flow Index
- frustration 事件频率 → 监控玩家体验
- bandit 臂收敛情况 → 验证系统稳定性

开发人员可用 `grep + jq` 从 `logs/game.log` 随时提取这些指标（见 10.4 节）。

---

## 12. 商业化衔接

> 以下为架构预留，不在本次实现范围内。

| 场景 | 触发条件 | 商业价值 |
|------|---------|---------|
| **精准助力 IAP** | frustration 高 + 得分接近目标 (>70%) | 玩家感觉"差一点就赢了"，购买意愿最高 |
| **挑战包** | expert 玩家 + 常规关卡太简单 | 难度即内容，高手愿意为挑战付费 |
| **提示经济** | casual 免费 3 次/关，normal+ 付费包 | 提示质量随技能自适应，始终感觉有用 |

### 道德底线

- 奖励函数硬编码优化**参与度**而非**付费前挫败**
- frustration > 0.8 触发无条件辅助，不考虑商业因素
- 所有难度参数通过 GM 面板完全透明可审计

---

## 13. 待解决问题与解决方案

> 以下为设计评审中识别的盲点和遗漏，按严重度分级，附解决方案和实施评估。

---

### 致命盲点

#### P0-1. dropBias 是唯一调节杠杆，但很多难度问题不在 bias 上

**问题**：`fragile + no_specials` 关卡的瓶颈是步数和特殊宝石缺失，无论 bias 多高都无法解决。Bandit 会在这类关卡上徒劳探索。

**解决方案：多杠杆 fallback 机制**

当 bias 无法解决问题时，启用额外的"救援"手段：

```lua
-- 触发条件：bias 已达最高臂(+0.45) 且连败 >= 3
if bandit.lastArm == 7 and failCount >= 3 then
    -- 救援杠杆1：降低目标分 10%（每多败 1 次再降 5%，最多降 25%）
    config.targetScore = floor(config.targetScore * max(0.75, 1.0 - 0.10 - 0.05*(failCount-3)))
    -- 救援杠杆2：赠送 2 步（上限 +4）
    config.maxMoves = config.maxMoves + min(4, 2 * floor((failCount-2)/2))
end
```

**实施评估**：✅ 本次实施 | 约 15 行 | 改动 `states.lua` 的 `startLevel()` | 不影响 Bandit 学习（救援是独立于 Bandit 的安全网）

---

#### P0-2. Bandit 无关卡上下文——所有关卡共享同一组臂

**问题**：Lv5 (5色 8×8) 和 Lv60 (7色 6×6 + no_specials) 对 bias 的需求完全不同，但共用一个 Bandit。在 Lv60 学到的偏好会污染 Lv61 的选择。

**解决方案：分桶上下文 Bandit**

按关卡特征将所有关卡分成 3-4 个"难度桶"，每个桶独立维护一组 7 臂：

```lua
-- 桶定义（基于关卡配置的客观特征）
local function getDifficultyTier(config)
    local hardModifiers = {"no_specials", "fragile", "small_board"}
    local hardCount = 0
    for _, m in ipairs(config.modifiers) do
        for _, h in ipairs(hardModifiers) do
            if m == h then hardCount = hardCount + 1 end
        end
    end
    if config.numGemTypes <= 5 then return 1 end   -- tutorial
    if hardCount >= 2 then return 4 end              -- extreme
    if hardCount >= 1 or config.numGemTypes >= 7 then return 3 end -- hard
    return 2                                          -- normal
end

-- Bandit 扩展：banditArms[tier][armIndex] = {alpha, beta}
-- 每个桶独立学习最优 bias
```

**实施评估**：✅ 本次实施 | 约 25 行 | 改动 `bandit.lua` | 存储从 7 组 alpha/beta → 28 组（4桶×7臂），仍 < 1KB

---

#### P0-3. 前 10 关冷启动期 = 最关键的留存窗口被放弃

**问题**：Day-1 留存主要取决于前 5-15 分钟。"前 10 关均匀先验"意味着纯新手和三消老手的首次体验完全相同。

**解决方案：3 关快速校准**

不等 10 关，在前 3 关结束时就根据初步表现设置 Bandit 先验：

```lua
-- Level 3 结束后触发
function Profile:quickCalibrate()
    local history = self.levelHistory -- 前 3 关数据
    local avgScoreRatio = mean(history, "scoreRatio")
    local avgCombo = mean(history, "maxCombo")

    if avgScoreRatio > 1.3 and avgCombo >= 3 then
        -- 老手信号：偏向挑战臂
        bandit:shiftPriors("challenge") -- arm 0-2 加 alpha
        self.skillScore = 0.6
    elseif avgScoreRatio < 0.7 then
        -- 新手信号：偏向辅助臂
        bandit:shiftPriors("assist")    -- arm 4-6 加 alpha
        self.skillScore = 0.2
    end
    -- 否则保持均匀先验（中等水平）
end
```

补充：在首次启动时可选"你玩过三消游戏吗？"（新手/有经验/高手），直接初始化先验，跳过校准期。

**实施评估**：✅ 本次实施 | 约 20 行 | 改动 `profile.lua` + `states.lua` | 显著改善首日体验

---

### 重要遗漏

#### P1-1. 缺少时间维度的感知

**问题**：一个每步想 10 秒的策略型玩家和一个每步 0.5 秒的随手点击型玩家，在当前画像中可能 skillScore 相同，但他们需要的体验完全不同。

**解决方案：新增 avgMoveTime 特征**

```lua
-- states.lua: 记录每步思考时间
local lastSwapTime = 0
function States.startSwap(r1, c1, r2, c2)
    local now = love.timer.getTime()
    if lastSwapTime > 0 then
        local thinkTime = now - lastSwapTime
        Profile:updateMoveTime(thinkTime) -- EMA 更新
    end
    lastSwapTime = now
    ...
end

-- profile.lua: 新增特征
-- avgMoveTime < 2s → "快速型"（可能是休闲随手点，也可能是高手秒解）
-- avgMoveTime 2-6s → "正常型"
-- avgMoveTime > 6s → "深思型"
-- 结合 skillScore 区分：低skill+快速=摆烂，高skill+快速=高手
```

**实施评估**：✅ 本次实施 | 约 15 行 | 改动 `states.lua` + `profile.lua` | 显著提升画像准确性

补充：回归间隔（天数）和 session 长度标记为 **V2**——需要在 Save 中加时间戳，改动稍大。

---

#### P1-2. 缺少 session 层面的节奏感

**问题**：连续 5 关都在心流区间但"全是苦战"会导致疲劳。好的 session 节奏应该张弛有度。

**解决方案：session 节奏调节器**

```lua
-- 追踪当前 session 中近 N 关的"紧张度"
local sessionTension = 0  -- 0=轻松, 1=紧张
function updateSessionTension(scoreRatio)
    local tension = scoreRatio < 1.1 and scoreRatio > 0.7 and 1 or 0
    sessionTension = sessionTension * 0.7 + tension * 0.3 -- EMA
end

-- Bandit 选臂时，如果 sessionTension > 0.7（连续苦战）
-- 临时给辅助臂加 alpha，制造一关"放松关"
-- 反之 sessionTension < 0.3（连续轻松），给挑战臂加 alpha
```

**实施评估**：⚠️ V2 实施 | 约 20 行 | 概念简单但需要 playtest 调参 | 和 Bandit 的探索/利用逻辑有耦合，可能产生意外行为，建议先积累真实玩家数据再设计

---

#### P1-3. 奖励函数是静态的——不同玩家的快乐峰值不同

**问题**：休闲玩家享受碾压（scoreRatio=1.5），核心玩家享受险胜（=1.05），完美主义者只在乎 3 星。一个固定的高斯中心 = 一刀切。

**解决方案：玩家自适应奖励中心**

```lua
-- 根据分型调整奖励函数参数
local rewardParams = {
    casual   = {center = 1.20, sigma = 0.35}, -- 乐于碾压
    normal   = {center = 1.05, sigma = 0.30}, -- 经典心流
    hardcore = {center = 1.00, sigma = 0.25}, -- 越紧张越好
    expert   = {center = 0.95, sigma = 0.20}, -- 享受极限挑战
}
local p = rewardParams[profile.archetype]
flowReward = exp(-((scoreRatio - p.center)^2) / (2 * p.sigma^2))
```

**实施评估**：✅ 本次实施 | 约 10 行 | 改动 `bandit.lua` 的 `computeReward()` | 低风险，直接提升个性化程度

---

#### P1-4. 玩家可以"钻空子"——故意失败获取帮助

**问题**：`连败 → frustration 升高 → 安全阀 → bias 拉高`，精明玩家可故意摆烂来降低难度。

**解决方案：识别"真实失败" vs "摆烂"**

```lua
-- 只有"真正尝试过"的失败才计入 frustration
function isGenuineFail(attempt)
    return attempt.scoreRatio > 0.3       -- 得分至少达到目标的 30%
       and attempt.movesUsed > attempt.maxMoves * 0.5  -- 至少用了一半步数
end

-- 摆烂检测（连续 3 次 scoreRatio < 0.2）
if consecutiveLowScores >= 3 then
    -- 不增加 frustration，不触发安全阀
    -- 可选：在 GM 面板标记 "suspected sandbagging"
end
```

**实施评估**：✅ 本次实施 | 约 10 行 | 改动 `profile.lua` 的 frustration 更新逻辑 | 低风险

---

#### P1-5. 不同 bias 下分数不可比（公平性问题）

**问题**：如果未来有排行榜，bias=+0.45 的玩家天然得分更高。

**解决方案**：

- 当前阶段：无排行榜，**不需要解决**
- 如果加排行榜：引入"标准化分数" = `rawScore / (1 + bias * 0.5)`，或者排行榜使用 `bias=0` 的"公平模式"

**实施评估**：🔮 未来按需 | 当前无排行榜，标记为已知限制即可

---

### 值得商榷

#### P2-1. 画像特征权重是手拍的

**问题**：`0.30 × scoreEfficiency + 0.25 × ...` 没有数据依据。

**解决方案（三阶段）**：

1. **当前**：权重作为 GM 面板可调参数，策划可实时调整观察效果
2. **Benchmark**：遍历若干权重组合（如 10 种），选 Flow Index 最高的组合
3. **V2**：如果有足够真实玩家数据，用相关性分析确定哪些特征对留存预测力最强

**实施评估**：✅ 阶段 1 本次实施（GM 可调）| 约 10 行 | 阶段 2-3 为 V2

---

#### P2-2. 合成玩家缺少情绪动力学

**问题**：真人连败后会"上头"（noise 飙升），学习有平台期，会退出游戏。合成玩家的参数是静态的。

**解决方案：增强合成玩家的行为动态**

```lua
-- 在 SyntheticPlayer:pickMove() 中
function SyntheticPlayer:onLevelEnd(passed)
    if not passed then
        self.consecutiveFails = self.consecutiveFails + 1
        -- "上头"效应：连败后 noise 临时升高
        self.effectiveNoise = self.noise + 0.05 * self.consecutiveFails
        -- 退出概率：连败 5+ 次有概率"退出 session"
        if self.consecutiveFails >= 5 then
            self.quitProbability = 0.2 * (self.consecutiveFails - 4)
        end
    else
        self.consecutiveFails = 0
        self.effectiveNoise = self.noise
        self.quitProbability = 0
    end
    -- 学习曲线：不是匀速，有 S 曲线特征
    -- 前期慢，中期快，后期又慢
    local sigmoidGrowth = self.growth * 4 * self.skill * (1 - self.skill)
    self.skill = self.skill + sigmoidGrowth
end
```

**实施评估**：✅ 本次实施 | 约 30 行 | 改动 `benchmark.lua` 的 SyntheticPlayer | 显著提升评估可信度

---

#### P2-3. 缺少灰度发布 / A-B 测试方案

**问题**：合成测试再好也不等于真人验证。

**解决方案**：

```lua
-- save.lua: 首次登录时随机分配
if not Save.data.ddaMode then
    Save.data.ddaMode = math.random() < 0.5 and "ml" or "legacy"
end

-- states.lua: 根据分配选择 DDA 模式
if Save.data.ddaMode == "ml" then
    -- 用 Bandit
else
    -- 用传统 ddaCurves
end

-- logger: 每条日志附带 ddaMode 字段，离线分析时可按组对比
```

回滚条件：如果 ML 组的 "连败≥5 次事件" 频率比 legacy 组高 20%，自动切回 legacy。

**实施评估**：⚠️ V2 实施 | 约 15 行代码但需要足够的真人玩家基数 | 当前阶段先用 benchmark + GM 面板手动切换验证

---

#### P2-4. ROI 不确定

**问题**：ML 系统增加 ~850 行代码，实际增益未知。

**解决方案**：不做"全量上线"的赌注，而是分阶段验证价值：

```
Phase 1: 实现核心 + benchmark
         → 如果 Flow Index 提升 < 5pp，说明 bias 这个杠杆本身天花板低，
           投入产出不值得，停在 Phase 1
Phase 2: 内部 QA playtest（5 人 × 各 50 关）
         → 主观体验是否明显更好？
Phase 3: 灰度发布 50% 用户
         → D1/D7 留存是否有差异？
```

每个 Phase 都是一个"止损点"。

**实施评估**：✅ 本次实施（分阶段 gate）| 0 行代码 | 项目管理层面的决策

---

### 总结：实施优先级

#### ✅ 本次迭代必做（与核心 ML 系统一起实施）

| # | 解决方案 | 新增代码量 | 理由 |
|---|---------|-----------|------|
| P0-1 | 多杠杆 fallback（降目标/加步数） | ~15 行 | 解决致命缺陷：bias 不是万能的 |
| P0-2 | 分桶上下文 Bandit（4 个难度桶） | ~25 行 | 解决致命缺陷：不同关卡类型需要不同学习 |
| P0-3 | 3 关快速校准 + 可选首次偏好 | ~20 行 | 解决致命缺陷：首日留存 |
| P1-1 | avgMoveTime 画像特征 | ~15 行 | 高价值低成本 |
| P1-3 | 自适应奖励中心 | ~10 行 | 千人千面的核心支撑 |
| P1-4 | 真实失败识别（反摆烂） | ~10 行 | 防止玩家博弈系统 |
| P2-1 | GM 面板可调权重 | ~10 行 | 策划调优工具 |
| P2-2 | 增强合成玩家动态 | ~30 行 | 评估可信度 |

合计 **+135 行**，总项目新增从 ~850 行 → ~985 行。

#### ⚠️ V2 迭代（需要真实玩家数据后）

| # | 内容 | 前置条件 |
|---|------|---------|
| P1-2 | Session 节奏调节器 | 需 playtest 数据确定参数 |
| P2-3 | 灰度 A/B 测试 | 需要玩家基数 |
| P1-1 补充 | 回归间隔 + session 长度 | 需 Save 加时间戳 |
| P2-1 补充 | 自动权重优化 | 需足够 benchmark 数据 |

#### 🔮 按需（当前不需要）

| # | 内容 | 触发条件 |
|---|------|---------|
| P1-5 | 分数标准化 | 加排行榜时 |
| P2-4 | ROI 止损 | 每个 Phase 结束时评估 |
