# Steady 上传链路（Fastlane → TestFlight）

代码侧已就绪：`.github/workflows/deploy.yml`（手动触发 deploy job）+ `fastlane/Fastfile`（gym 归档 + ASC API key 上传）。**链路跑通需要用户完成以下一次性配置**（预计 30 分钟，全部是"只有用户能做"项）。

## 用户步骤清单

### 1. Apple 开发者账号（前置，$99/年）
注册 https://developer.apple.com/programs/ 。这是所有后续步骤的前置。

### 2. App Store Connect 建 App 与商品
- App Store Connect → My Apps → 新建：Bundle ID `sh.steadyhabit.Steady`，名称 Steady
- In-App Purchase → Non-Consumable：`sh.steadyhabit.lifetime`，价格 $12.99
- 税务/收款：Agreements, Tax, and Banking → W-8BEN + 银行卡 + Paid Apps 协议

### 3. 生成 App Store Connect API Key
- App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → 新建（Role: App Manager）
- 得到三样东西：Key ID、Issuer ID、下载的 `.p8` 私钥文件
- 转 base64：`base64 -i AuthKey_XXXX.p8 | pbcopy`

### 4. 建 match 证书仓库
- 新建一个**私有** GitHub 仓库（如 `wa15aa/steady-certs`）
- 本机跑一次初始化（需要开发者账号登录态）：
  ```
  cd steady && bundle install
  ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_BASE64=... \
  MATCH_GIT_URL=git@github.com:wa15aa/steady-certs.git \
  fastlane match appstore
  ```
  第一次会要求设 MATCH_PASSWORD（记住它）。

### 5. 配 GitHub Secrets（steady 仓库 → Settings → Secrets → Actions）
| Secret | 内容 |
|---|---|
| `ASC_KEY_ID` | 第 3 步的 Key ID |
| `ASC_ISSUER_ID` | 第 3 步的 Issuer ID |
| `ASC_KEY_BASE64` | 第 3 步 .p8 的 base64 |
| `MATCH_PASSWORD` | 第 4 步设的密码 |
| `MATCH_GIT_URL` | 第 4 步的证书仓库地址 |

### 6. 触发
GitHub → steady 仓库 → Actions → "Deploy to TestFlight" → Run workflow。

## 本地验证（不需要账号）
`bundle exec fastlane archive_only` 只验证归档步骤（需本机有签名证书）。
