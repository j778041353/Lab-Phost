# Lab Phost 在线投票 · 部署指南

这是可部署的正式版**源码**，不是已上线的网址。需要你自己创建 Supabase 和 Vercel 项目；本文件夹没有任何账号密钥。

## 1. 创建数据库

1. 打开 https://supabase.com/dashboard ，注册/登录，点击 **New project**，创建新项目。
2. 在项目的 **SQL Editor** 中新建查询，粘贴 `schema.sql` 全部内容并执行。**仅在新的空项目运行一次**，不要在已有表的项目重复执行。
3. 在 **Authentication → Providers → Email** 启用邮箱登录；建议保持 **Confirm email** 开启。为减少滥用，可在 Authentication 设置中配置验证码、邮箱发送限制。
4. 从项目的 **Connect** 或 **Project Settings → API** 获取 **Project URL** 和 **publishable key**（旧项目可能显示 anon key）。将两者填入 `config.js`。**不要**使用 `service_role` 或 `secret` key。`config.js` 中的 publishable key 会公开给访问者，这是预期行为。

## 2. 部署到 Vercel

1. 打开 https://vercel.com/ 注册/登录。推荐创建一个 GitHub 仓库，上传 `index.html`、`config.js`、`schema.sql` 和 `README.md`（注意：不要上传任何 secret key）。
2. 在 Vercel 点击 **Add New → Project**，导入仓库，Framework Preset 选 **Other**，保持根目录为项目根目录，不需要构建命令，点击 Deploy。
3. 部署完成后，Vercel 会提供 `https://你的项目名.vercel.app`。这是你发给朋友的**唯一参与链接**，网页内没有邀请/分享/二维码按钮。
4. 回到 Supabase **Authentication → URL Configuration**：Site URL 设为你的 Vercel 网址；Redirect URLs 也加入同一个网址（如 `https://你的项目名.vercel.app/**`）。否则邮箱验证后可能跳转错误。
5. 如果改了 `config.js`，提交代码并等待 Vercel 自动重新部署。

不想用 GitHub：也可以通过 Vercel CLI 在本地目录部署，但需要在电脑上安装并登录 Vercel CLI。

## 3. 实际测试

- 使用两个不同邮箱注册并完成邮箱验证，在两台设备/两个浏览器登录。
- 账号 A 添加「玉米」后，账号 B 等待约 5 秒即可看到「玉米」，可选择它并添加「芝麻」。
- A、B 分别提交后，退出重登应只显示结果，无法继续添加或投票。
- 新建选项立即公开且不可更改；**其创建者的那一票只有在正式提交后才计入结果**。
- 截止时间：2026 年 10 月 10 日 23:59 温哥华时间（PDT；UTC 2026-10-11 06:59）。数据库在截止时拒绝新增和提交，即使用户修改本机时间也无效。

## 4. 注意事项

- 限制是**每个账号一次**，不是现实世界中每个人一次；同一个人若注册多个邮箱，仍可能用多个账号参与。若要更严格限制，需要额外的邀请名单/人工审核。
- 投票选项对所有**已登录**参与者可见；任何拿到链接的人都可以注册，链接不是访问控制。若希望只有你邀请的人能参与，需要添加邀请白名单。
- 页面每 5 秒拉取一次结果（近实时），不是毫秒级推送。网络断开后会在恢复时继续刷新。
- 目前所有已登录参与者都能看到汇总票数，不能读取其他人的单独投票记录。
- `schema.sql` 内的函数是数据库侧的限额和提交约束，不依赖浏览器按钮的限制。
- 如果之后改截止日期，**必须同时**修改 `schema.sql` 中 `poll_deadline()` 的 UTC 时间和 `index.html` 中的截止显示及 JS `deadline`，并在 Supabase 更新函数。
