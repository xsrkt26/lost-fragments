# 当前架构图记录

文档状态：已按当前代码更新。本文用于辅助理解，不替代 `../02_Tech/01_System_Architecture.md`。

## 一、运行主流程

```mermaid
graph TD
    START((启动)) --> MENU[MainMenu]
    MENU -->|开始/继续| HUB[HubScene]
    HUB -->|当前路线节点| ROUTE{RouteConfig 节点}
    ROUTE -->|battle / boss_battle / elite_battle| BATTLE[MainGameUI + BattleManager]
    ROUTE -->|shop| SHOP[ShopScene]
    ROUTE -->|event / reward / cutscene 占位| EVENT[EventScene]
    BATTLE -->|胜利选择奖励| REWARD[RewardGenerator]
    REWARD --> RUN[RunManager]
    SHOP -->|购买/刷新| RUN
    EVENT -->|事务应用选择| RUN
    RUN -->|advance_route_node| HUB
    RUN -->|第6层完成| MENU
    BATTLE -->|失败| MENU
```

## 二、核心分层

```mermaid
graph TD
    subgraph Data[静态数据]
        Items[data/items/*.tres]
        Ornaments[data/ornaments/ornaments.json]
        Tools[data/tools/tools.json]
        Events[data/events/events.json]
        Routes[data/routes/routes.json]
        Economy[EconomyConfig]
    end

    subgraph Run[跨场景运行状态]
        RM[RunManager]
        Save[SaveManager]
        RNG[Serializable RNG]
    end

    subgraph Battle[局内逻辑]
        BM[BattleManager]
        BPM[BackpackManager]
        TE[ToolEffect]
        IR[ImpactResolver]
        SP[SequencePlayer]
        GA[GameAction]
    end

    subgraph UI[表现层]
        Hub[HubScene]
        MainUI[MainGameUI]
        Shop[ShopScene]
        EventUI[EventScene]
        Tooltip[GlobalTooltip]
        Feedback[GlobalFeedback]
    end

    Data --> RM
    RM --> Save
    RM --> BM
    BM --> BPM
    BM --> TE
    BM --> IR
    IR --> GA
    BM --> SP
    SP --> MainUI
    UI --> RM
```

## 三、局内抽取与撞击

```mermaid
sequenceDiagram
    participant Player
    participant UI as MainGameUI
    participant BM as BattleManager
    participant BPM as BackpackManager
    participant IR as ImpactResolver
    participant SP as SequencePlayer
    participant GS as GameState

    Player->>UI: 点击捕梦
    UI->>BM: request_draw()
    BM->>BM: 进入 DRAWING / RESOLVING
    BM->>GS: 扣除梦值（饰品可修正）
    BM-->>UI: item_drawn(item_data)
    BM->>BM: 处理抽取后效果与撞击入队
    loop 撞击队列
        BM->>IR: resolve_impact()
        IR-->>BM: Array[GameAction]
        BM->>SP: play_sequence(actions)
        SP->>GS: 按动作同步数值
    end
    BM->>BM: 回到 INTERACTIVE 或发出 pending finish
```

## 四、长期构筑写入

```mermaid
graph LR
    Reward[奖励选择] --> Grant[RunManager.apply_reward / grant_item]
    Shop[商店购买] --> Grant
    Event[事件效果] --> EventTxn[RunManager.apply_event_choice]
    EventTxn -->|成功| Grant
    EventTxn -->|失败| Rollback[回滚快照]
    Grant --> Deck[current_deck]
    Grant --> Backpack[current_backpack_items]
    Grant --> Pending[pending_item_rewards]
    Grant --> Ornaments[current_ornaments]
    Grant --> Shards[current_shards]
```

## 五、测试与发布

```mermaid
graph TD
    Change[代码/资源/文档改动] --> Gut[GUT: tools/run_tests_silent.ps1]
    Change --> Smoke[Strict Scene Smoke]
    Release[发布] --> Precheck[export_windows_release.ps1 -PrecheckOnly]
    Precheck --> Gut
    Precheck --> Smoke
    Precheck --> Manifest[package/*.manifest.json]
```

## 当前图中未覆盖的已知限制

- 整理背包当前仍复用局内 UI，但已通过独立浮层模式处理基础关闭入口、输入上下文和布局覆盖；继续扩展专属功能时再拆独立 scene。
- 道具系统基础运行图已接入局内 UI、`BattleManager`、`RunManager` 和奖励/商店/事件入口；当前图未展开每个具体道具效果分支。
- GitHub Releases 自动发布已接入，按 `v*` tag 触发。
