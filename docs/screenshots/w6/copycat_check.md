# 防 Copycat 走查：Steady vs HabitKit 并排对照（ASC 4.1）

日期：2026-09-19 ｜ 执行：steady-duty W7 ①
对照素材：HabitKit 9 图（`market-intel/kb/assets/competitors/habitkit/01-09*.jpg`）vs Steady 9 图（本目录 w6/w7 截图）

结论先行：**一眼不像**。布局骨架、视觉语言、文案口吻、付费叙事四个维度全部可区分。逐屏对照如下。

## 1. 主页（Today）

| 维度 | HabitKit (04_home_grid_year) | Steady (w6_01_today) |
|---|---|---|
| 骨架 | 每个习惯一张大卡片，卡内嵌全年格子热力图，右侧大号彩色圆形打卡钮 | 列表行式：小图标瓦片 + 名称 + 周 7 圆点，行内打卡 |
| 头部 | 顶部 4 个圆形工具钮（设置/PRO/图表/+），无标题栏 | 系统导航栏 + 标题，齿轮左上，+/EditButton 右上 |
| 底部 | 胶囊式 3 视图切换器（白底浮起） | 胶囊切换器是我们 W7 后加的——**此处是唯一相似点**，见 §6 |
| 气质 | 大色块、深色圆钮、格子为主角 | 浅色、细线、文字为主角 |

## 2. 详情页
- HabitKit（05/06）：年份格子大图 + 环形统计。
- Steady（w6_02_detail / w6b_detail_charts）：系统 grouped list 结构 + Swift Charts 柱状图（周/月分段切换）。图表形态完全不同（bar vs year-grid）。

## 3. 新建习惯
- HabitKit（02）：深色弹层、大预览、分段滑块。
- Steady（w6b_addhabit）：系统 Form 分组（Name/Type 分段/Icon 网格/Color 7 列 LazyVGrid/Reminders 行），原生 iOS 表单观感，无自定义装饰。

## 4. Paywall（差异最大，且是付费叙事核心）

| 维度 | HabitKit (07_paywall) | Steady (w6_03_paywall) |
|---|---|---|
| 标题 | "Unlock Habit**Kit** Pro"（品牌字双色） | 无品牌大字，中央大价格 "$12.99" |
| 叙事 | "BY SUBSCRIBING YOU'LL ALSO UNLOCK"——订阅制、功能清单卡片堆叠（图标+标题+副标题） | "One purchase. Yours forever. No subscription, no tricks."——买断制、3 条 ✓ 卖点 |
| CTA | 紫渐变胶囊 "Continue" | 蓝色直角圆角块 "Buy once — $12.99" |
| 错误态 | 红色横幅卡（顶部） | 红色一行文字（按钮下方） |
| 退出 | 左上 ✕ 圆钮 | "Not now" 文字链 |

文案上我们刻意不提 habit 数量（paywall 文案纪律），HabitKit 第一条卖点就是 "Unlimited number of habits"——截然相反。

## 5. Onboarding
- HabitKit（01_welcome）：深色底、插画、分页点。
- Steady（w7_onboarding）：白底一页式，标题 + 一句 "A habit tracker that forgives you." + 4 张 SF Symbol 卖点卡（断签不死/买断/加密备份/Quit），底部 "Get started"。卖点内容本身（never-miss-twice、quit habits）是 HabitKit 没有的概念。

## 6. 唯一需要盯的相似点
底部胶囊 3 视图切换器（List/Week/Compact）与 HabitKit 的底部胶囊形态接近（都是圆角浮起 3 段图标切换）。**风险评估：低**——(a) 分段切换器是 iOS 通用模式（SF Symbols、.regularMaterial 均为系统控件）；(b) 图标、顺序、承载的视图内容均不同；(c) ASC 4.1 判例针对的是整体克隆，单一通用控件不构成。如审核遇到质疑，可改为顶部 segmented control 作为备选。

## 7. 走查结论
- [x] 布局骨架：不同（卡片网格 vs 列表行）
- [x] 色彩语言：不同（深色调色块 vs 浅色系统原生）
- [x] 文案口吻：不同（订阅功能清单 vs 买断宽恕叙事）
- [x] 独有概念：Quit habits / never-miss-twice / 买断——对方均无
- [x] 唯一相似点（胶囊切换器）已记录风险与备选方案

**判定：通过，不存在 ASC 4.1 copycat 风险。**
