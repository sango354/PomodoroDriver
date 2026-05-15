# 系統規格 05：解鎖、情境與內容系統

## 1. 目的

本系統提供中期目標，並支援模組化內容更新。其範圍包含可解鎖內容、環境情境狀態與內容資料結構。

## 2. 設計目標

- 使用者隨時都應有接近可達成的解鎖目標
- 環境變化要讓重複使用不容易疲乏
- 內容新增應盡量採資料驅動

## 3. 解鎖分類

- 房間擺設
- 背景主題
- 環境音變體
- 角色表情或姿態
- 收藏物
- 事件內容

## 4. 解鎖來源

| 解鎖來源 | 範例 |
| --- | --- |
| 貨幣購買 | 使用 Focus Points 購買房間物件 |
| 等級里程碑 | 等級 3 解鎖新房間皮膚 |
| Bond 里程碑 | Bond 2 解鎖休息事件 |
| 條件達成 | 完成 5 次夜間 session 解鎖收藏 |
| 任務獎勵 | 解鎖特殊外觀 |

## 5. 功能需求

| ID | 需求 | 優先級 |
| --- | --- | --- |
| UC-001 | 系統需以資料形式儲存解鎖定義 | P0 |
| UC-002 | 系統需支援貨幣型解鎖 | P0 |
| UC-003 | 系統需支援等級與 Bond 條件解鎖 | P0 |
| UC-004 | 系統需支援條件型解鎖 | P1 |
| UC-005 | 使用者可裝備已解鎖的房間與情境內容 | P1 |
| UC-006 | 使用者可預覽未解鎖內容 | P1 |

## 6. 情境模型

### 6.1 維度

- 房間
- 時段
- 天氣
- 環境音主題

### 6.2 MVP 情境內容

- 房間：3 種
- 時段：2 種，day、night
- 天氣：2 種，clear、rain
- 環境音：4 組

## 7. 內容規則

- 未解鎖內容應盡可能顯示解鎖條件
- 內容可用性不應阻塞核心 session 使用
- 情境變化可影響角色台詞選擇與解鎖條件判定

## 8. 資料驅動內容表

- 內容定義表
- 解鎖條件表
- 房間 preset 表
- 環境音定義表
- 台詞條件對應表
- 事件條件對應表

## 9. UI 需求

- 收藏 / 背包畫面需按內容類型分組
- 未解鎖項目應顯示條件文字
- 裝備內容最好即時生效

## 10. 分析事件

- `content_previewed`
- `content_unlocked`
- `content_equipped`
- `context_switched`

## 11. 依賴

- 成長與回饋系統
- 角色互動系統
- 任務與成就系統

## 12. 目前實作狀態

Last synced: 2026-05-13

- 解鎖內容目前以背景內容骨架為主，runtime 定義在
  `game/data/background_defs.json`，文件表格副本在
  `docs/product-spec/data/csv/background_defs.csv`。
- Store 面板已可列出背景內容、顯示已解鎖狀態、以 Focus Points 購買鎖定項目，並將購買結果存入
  `user://save.json` 的 `unlocked_content`。
- Room Background 01 與 Room Background 02 目前預設解鎖，並可從底部 `BG` 選單切換。
- Lo-fi/Room Spine 背景控制仍保留，但目前主畫面實際視覺背景已切到 Taxi 介面與 3D 街景 exterior。
- Taxi 3D exterior 目前不是內容表驅動，而是由
  `game/scripts/taxi_street_world_controller.gd` 內的 `MAP_LAYOUTS`、
  `HOUSE_MODELS`、`STREET_PROPS` 和 sky panorama 常數定義。
- Taxi 3D exterior 使用的 runtime GLB/貼圖子集位於
  `game/assets/Generated/JapaneseStreet3D/`；原始 Unity 資產
  `game/assets/Japanese_Street/` 仍視為未追蹤來源素材。
- 接下來若要讓街景、地圖、天空循環或 exterior 主題成為可解鎖內容，需要把目前的 code-defined map/art
  selection 抽到內容定義表，並補上 `content_equipped` / `context_switched` 類事件。
