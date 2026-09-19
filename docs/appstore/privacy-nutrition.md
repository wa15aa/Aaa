# App Store 隐私问卷（Nutrition Labels）填写答案
2026-09-18 · 依据：steady 代码实际行为（无账号/无分析/无广告/无第三方 SDK）

## 总答案
**Data Collection: No** — App 不收集任何数据。

ASC 问卷路径：App Store Connect → App → App Privacy → Data Types：
- Contact Info: No
- Health & Fitness: No
- Purchases: No（StoreKit 购买由 Apple 处理，developer 侧拿不到身份，选 "not collected"）
- User Content: No（习惯数据只在设备/用户自己的 iCloud，不离开用户控制域——按 Apple 定义不算"collected"）
- Identifiers / Usage Data / Diagnostics / Location / Browsing: 全部 No

最终页面显示：**"The developer does not collect any data from this app."** —— 这本身是卖点，可写进描述第二屏。

## Privacy Policy URL
- 文件已备好：book 仓 `habit-landing/privacy.html`（静态单页，中英口径见 listing.md）
- 发布选项（任选其一，都需要用户登录态）：
  1. `npx surge habit-landing/`（需 surge 登录，之前域名 steadyhabit.surge.sh）
  2. steady 仓开 GitHub Pages 托管 docs/
  3. 任何静态托管
- ⚠️ 上架前替换文件内占位联系邮箱（HTML 注释有 TODO 标记）

## 加密合规（Export Compliance）
AES-GCM 备份用了系统 CryptoKit → 属于豁免类（Apple 系统加密）：
Info.plist 加 `ITSAppUsesNonExemptEncryption = false` 即可免每年自证。**待办：上架构建前加进 project.yml**。
