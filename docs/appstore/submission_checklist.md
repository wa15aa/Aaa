# Steady 1.0 上架 checklist（W8，死线 2026-12-11 提审）

状态图例：✅ 备好 / 🔲 待做 / ⛔ 阻塞（开发者账号）

## 账号与工程
- ⛔ 开发者账号注册+$99（用户决定延后；TestFlight/沙盒/提审全堵在这）
- 🔲 账号下来后：ASC 建 App 记录（bundle id sh.steadyhabit.Steady）、App Group capability 在 portal 注册 `group.sh.steadyhabit.Steady`（Widget 需要）
- 🔲 StoreKit 配置文件：IAP `steady.pro.lifetime` $12.99 non-consumable（代码已按此 id？上架前核对 StoreKitManager）
- ✅ 出口合规：ITSAppUsesNonExEncryption=NO（仅用 CryptoKit）已写 Info.plist
- 🔲 Release 构建 + 真机 smoke（含 Widget 真机走查）

## 物料
- ✅ listing.md：en-US 名/副标题/关键词/描述/What's New（2026-09-19 含 Quit 等全卖点）
- ✅ es-MX 关键词位段落（listing.md 附录）
- 🔲 ASC 截图 R2 三帧（已发飞书待批；批后 ✅）
- ✅ App 图标（docs/screenshots/appstore/ 同批备）
- ✅ 隐私营养标签文案（privacy-nutrition.md）
- ✅ 隐私政策 URL：https://steadyhabit.surge.sh/privacy.html（邮箱 772751110@qq.com 已上线）
- 🔲 年龄分级问卷（无不良内容，预期 4+）

## 审核材料
- 🔲 Review Notes：说明买断制 IAP、演示数据无需账号、 quit 习惯语义（防审核员误判"打卡反向"）
- 🔲 截图审批 R2 通过后上传 ASC
- ⛔ Submit for review（账号+Build 上传后）

## 上架后立刻（W8 数据三件套）
- 🔲 waitlist 欢迎邮件模板（给 habit-landing 的 1 个订阅者及后续）
- 🔲 App 内反馈通道（设置页 mailto 已有 ✅，上架后确认邮箱收信）
- 🔲 匿名统计：landing 打点已跑（visit/signup），App 内零埋点原则不变
