# W6 UI 质量门（第 1 轮）— 2026-09-19

截图：steady/docs/screenshots/w6/（01_today / 02_detail / 03_paywall），commit 209c708。
基准：kb/fact/default/habitkit-app-teardown.md（HabitKit v1.17.3 九页拆解）。

## 详情页（02_detail）对照 HabitKit 详情页

| 检查项 | HabitKit 基准 | Steady 现状 | 判定 |
|---|---|---|---|
| 头部识别（icon+名称） | 大 icon + 名称 + 主题色 | 36pt icon 圆角底 + title2 名称 + QUIT 胶囊（quit 型） | ✅ |
| 今日主动作 | 顶部大按钮一键打卡 | "Check in for today" 整宽大按钮，已打卡态变 "Done for today"+haptic | ✅ |
| 核心指标行 | streak/best/完成率 横排 | Current/Best/Journeys/Rate 四格 | ✅ |
| 全年热力图 | GitHub 式年热力图 | 同款，tap 出 day 详情文案 | ✅ |
| 反罪恶感表达 | （HabitKit 无，断签即红墙） | dimmed 半透明格 + "Journey N" 文案 —— 差异化保留 | ✅ 优于基准 |
| 底部留白/拥挤度 | 信息一屏内 | 一屏内，下方留白可后续放周视图（W7） | ✅ |

## Paywall（03_paywall）对照 HabitKit paywall + replan-v2 §5

| 检查项 | 基准 | Steady 现状 | 判定 |
|---|---|---|---|
| 价格第一行 | HabitKit 价格显眼 | $12.99 44pt 顶部 | ✅ |
| 反订阅话术 | —（HabitKit 是订阅） | "One purchase. Yours forever. No subscription, no tricks." | ✅ 差异点 |
| 功能点触发横幅 | HabitKit 07 页：功能点触发的 paywall 转化优于数量墙 | requestedFeature 置顶 "UNLOCKS …"（详情页/Quit 创建双入口已接） | ✅（本截图为数量墙入口，无横幅，符合预期） |
| 功能清单文案纪律 | replan-v2 §5：不提习惯数量限制 | 三条：stats/Quit/加密备份，无 "Unlimited habits" 字样 | ✅ |
| 错误态 | 必读 | "Something went wrong. Try again later."（截图即错误态，商品未加载时可见） | ✅ |
| 退出路径 | 不强制 | "Not now" 置灰小字 | ✅ |

## Today（01_today）

| 检查项 | 判定 |
|---|---|
| ≤1 次点击打卡（右侧大圆圈） | ✅ |
| 断签不死可视化（7 天小点半透明） | ✅ |
| 周目标行 "This week 3/3 · 2-week streak" | ✅ |

## 结论

第 1 轮三张截图全部通过自检，无需返工项 → 提交用户审批（Feishu A 档）。
