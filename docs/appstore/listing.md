# App Store 上架文案（en-US 主文案 + zh-Hans 备用）
2026-09-18 · 对应 MVP_SPEC §0-3 · 上架时直接粘贴到 App Store Connect

## en-US（主）

**Name (30 字符上限)**（ASO 卡：关键词前置排名更优，HabitKit 证据 98% 搜索下载）
Habit Tracker - Steady

**Subtitle (30 字符上限)**（卖点词即关键词；与标题零重复）
Never miss twice, streaks live

**Keywords (95/100 字符，逗号分隔无空格；已与标题副标题去重、无复数变体)**
recovery,daily,routine,reminder,widget,atomic,goal,planner,consistency,heatmap,focus,discipline

**Promotional Text (170 字符，可不改版本随时更新)**
Missed a day? Your streak survives. Steady uses never-miss-twice: one miss is data, two break the chain. One-time $12.99, no subscription, your data never leaves your hands.

**Description**
Most habit trackers punish you. Miss one day and watch your streak hit zero — along with your motivation.

Steady is built on a different rule: never miss twice. One $12.99 purchase, no subscription — and encrypted iCloud sync, so your history survives a new phone.

• ELASTIC STREAKS — One missed day dims the square but keeps your streak alive. Only two misses in a row start a new journey segment. Your history is never erased; it becomes your story.
• QUIT HABITS, TOO — Quitting sugar or smoking? A quit habit is clean by default; you only mark slip days, and one slip never breaks you.
• WEEKLY RHYTHMS — Gym 3x a week? Track by weekly targets, not daily guilt.
• STATS THAT FORGIVE — Weekly and monthly charts count your consistency honestly — slips included, nothing erased.
• ONE-TAP CHECK-IN — The app opens to today's list. One tap, a gentle haptic, done. No onboarding, no account, no quiz.
• GITHUB-STYLE HEATMAP — Your whole year at a glance. Tap any square to see that day.
• NEVER LOSE DATA — Local-first storage with encrypted daily backup to your iCloud Drive. Delete and reinstall, everything comes back.
• ONE PRICE, FOREVER — $12.99 lifetime. The price is printed on the paywall's first line. No subscription, no trials that convert, no dark patterns.

Three views (list, week board, compact), home-screen widget, up to 3 reminders per habit, custom day-end for night owls.

Free to start: 3 habits with full functionality. Upgrade once when you want more.

Built by an indie developer who broke one too many streaks.

**What's New (1.0)**
Initial release: elastic streaks that survive a missed day, quit-habit tracking (slip days don't break you), yearly heatmap + weekly/monthly charts, weekly-frequency habits, up to 3 reminders per habit, home-screen widget, encrypted iCloud backup. One-time purchase, no subscription — ever.

---

## zh-Hans（备用，如国区上架）

**名称**：Steady：不断签的习惯
**副标题**：断一天，不清零

**描述要点**（直译自 en，上架时再润色）：
多数习惯 App 在惩罚你。断签一天，连续天数归零，动力一起归零。Steady 的规则是"别断两天"：断一天格子变暗但 streak 保留，连断两天才开启新一段旅程——历史永远保留。还能戒习惯：戒糖戒烟默认今天是守住的，只标破戒天，破一次不清零。每周 N 次节奏、一键打卡、GitHub 式年度热力图、周/月图表、每习惯 3 条提醒、桌面小组件、加密 iCloud 备份。$12.99 一次买断，价格印在付费页第一行，无订阅无套路。

---

## 截图-文案配对建议
| 截图 | 顶部标题文案（ASO 惯例：截图上加粗短句） |
|---|---|
| 01_today | Missed a day? You're still in. |
| 02_detail | Every streak survives. Counted forever. |
| 03_paywall | $12.99 once. No subscription. |

（2026-09-19 改版：采纳 sage aso-screenshot-paywall-ab 三帧假设——首帧即抛差异化、机制文案>功能文案；03 保留具体价格版，比 "One price" 更过滤。合成脚本 tools/compose_asc.py）

## ASO 依据（2026-09-18 sage 卡 aso-keyword-strategy-habit 采纳）
- 关键词前置标题 + 副标题卖点词；"habit tracker" 难度 64 走长尾，差异化词（never miss twice / streak recovery 语义）意图精准
- 本地化倍增：上架时加 Spanish (MX) locale 吃美区额外 100 字符关键词位（无需真翻译）

## es-MX（关键词位倍增用，2026-09-19 备）

**Name**: Habit Tracker - Steady（同 en-US，品牌词不动）
**Subtitle**: Never miss twice, streaks live（同上）
**Keywords (es-MX 专属 100 字符，与 en-US 不重复即可各算各的)**:
habitos,diario,racha,recordatorio,meta,seguimiento,constancia,widget,gratis,salud,productividad
**说明**：es-MX 的 name/subtitle/keywords 会参与美区搜索；description 可留英文（ASO 惯例），上架时若时间充裕再翻。
- [verify 2027-01-15] 预测：主词 4 周进不了前 50，长尾应进前 20；全灭则投 ASA 验证词包
- [候选 2026-09-19] sage YouTube 语料：ADHD 人群是 habit tracker 蓝海——W8 前关键词迭代时评估 "adhd" 进 100 字符位（换哪个词出去到时再定）；Quit 卖点不进获客第一层文案，但 replan-v2 §6 允许长尾关键词位收 quit smoking tracker / streak recovery / no subscription（W8 一并评估）

## Spanish (MX) locale 关键词位（本地化倍增，美区额外 100 字符）
- Name/Subtitle 直接复用 en-US（无需真翻译）
- Keywords (94/100)：habitos,racha,seguimiento,diario,rutina,recordatorio,productividad,constancia,proposito,habito
- 依据 kb aso-keyword-strategy-habit：美区最多索引 10 locale，MX 是经典免费位

## 待用户侧配合
- 截图上传到 ASC 需开发者账号（waiting_on_user.md #1）
- 关键词上线后 2 周看搜索排名再迭代（记入 growth KB 对账）

## 1 月旺季版话术（Quitter's Day 后启用，2027-01-08 起，09-24 交叉对账修正：Quitter's Day 2027=01-08 第二个周五）
依据：sage 调研 kb/fact/default/january-peak-season-calendar.md——Quitter's Day 后鸡血素材 ROAS -22%、微习惯/留存叙事 +42%。届时切换：

**Promotional Text（1 月版，170 字符）**
Everyone quits on Quitter's Day. You don't have to. Steady forgives a missed day — your streak survives, your history stays. One-time $12.99, no subscription.

**Reddit/社媒话术（1 月版）**
It's Quitter's Day — the Friday when ~80% of New Year's resolutions die. The streak apps you downloaded last week are about to show you a big fat zero. That zero is why people quit twice. I built Steady around the opposite rule: miss one day, nothing breaks. Miss two, you start a new journey segment — your history is kept, not erased. $12.99 once, no subscription. (happy to share the link if allowed)

**ASO 副标题候选（1 月版）**："Survive Quitter's Day"（30 字符内，A/B 测）

**节奏**：12/26-1/7 用现行"新年计划"获客口径；1/8 起切上面这套留存叙事。
