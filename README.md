# Family tree update — 15 October 2026

The October teammate baseline is integrated with a group-based Family tree. Start with the [feature plan](DOCUMENTATION.FAMILY.TREE01.1.md) and [current implementation handoff](DOCUMENTATION.FAMILY.TREE01.REVIEW.md). Family → Family tree provides group connections, administrator proposals, unanimous tree-merge approval and disconnection. The existing September portable ZIP predates this feature; it has not been replaced by this source update.

# Global Village App (week4)

Global Village 社区应用:Flutter 前端 + 四套 Docker 后端服务(登录 Auth / 社区 Community / 家庭 Family / 聊天 Chat,聊天含好友申请与消息数据库)。

## 环境要求

1. [Docker Desktop](https://www.docker.com/products/docker-desktop/) — 已启动运行(一键模式只需要这个)
2. [Flutter SDK](https://docs.flutter.dev/get-started/install) — 仅开发模式需要(`flutter doctor` 无红色错误,需要 Chrome 浏览器)

## 启动方式一:一键运行(推荐,无需安装 Flutter)

双击 **RunProdWeb.cmd**。它会自动完成:

1. 启动全部四套 Docker 后端(首次会构建镜像,约 2-5 分钟)
2. 写入演示账号、好友关系和演示群(幂等,重复运行无副作用)
3. 用 nginx 容器托管已预编译的前端(`build\web`)并打开浏览器

应用地址:http://localhost:7357 。停止服务:双击 `StopPublicDemo.cmd`(或 `docker compose -f <各 compose 文件> stop`,再加 `docker rm -f global-village-web`)。

## 启动方式二:开发模式(需要 Flutter SDK)

### 第 1 步:启动全部后端服务(需要 Docker Desktop 已运行)

在项目根目录(本文件夹)依次执行:

```powershell
docker compose -f docker-compose.yml up -d --build
docker compose -f docker-compose.auth.yml up -d --build
docker compose -f docker-compose.family.yml up -d --build
docker compose -f docker-compose.chat.yml up -d --build
```

### 第 2 步:验证服务健康

```powershell
curl.exe http://localhost:3000/health
curl.exe http://localhost:3002/health
curl.exe http://localhost:3003/health
curl.exe http://localhost:3004/health
```

四个都应返回 `{"ok":true,...}`。

### 第 3 步:启动前端

双击 **RunWeb.cmd**(首次运行会自动 `flutter pub get`,并自动打开 Chrome)。

应用地址:http://localhost:7357

> 提示:修改 `lib/` 代码后,如需更新一键模式的前端,请用 RunProdWeb.cmd 注释里的完整命令(含全部 4 个 `--dart-define`)重新 `flutter build web`。

## 手机 APP(Android)

项目可打包为 Android APP,包含全部现有功能(登录/社区/家庭/聊天、语音/视频通话、群聊通话与群主管理员管理)。已构建好的 APK 在 `dist/` 目录:

| 文件 | 说明 |
|---|---|
| `GlobalVillage-app-universal.apk` | 通用包(92MB,任何 Android 手机) |
| `GlobalVillage-app-arm64.apk` | 64 位包(33MB,近年主流手机推荐) |
| `GlobalVillage-app-arm32.apk` | 32 位包(25MB,老旧手机) |

### 手机使用步骤

1. 找一台电脑按「启动方式一」运行 RunProdWeb.cmd(手机与电脑连**同一 WiFi/局域网**)
2. 把 APK 发到手机(微信/USB 均可)安装,允许「未知来源/安装未知应用」
3. 打开 APP,登录页**底部「Server: ...」**→ 填运行后端那台电脑的局域网 IP(如 `192.168.1.50`)→ Save
4. 用测试账号登录(账号见上文),所有功能与网页版一致

### 常见问题

- **电脑 IP 查看**:`ipconfig` 看「IPv4 地址」(选路由器网段的,如 `192.168.x.x`;忽略 172.x/169.254.x/26.x 等虚拟网卡地址)
- **手机连不上(最常见)**:Windows 防火墙拦截。**双击项目根目录的 `AllowPhoneAccess.cmd`**(右键以管理员身份运行 / 同意 UAC),一键放行 3000-3004 与 7357 端口;也可手动:
  `netsh advfirewall firewall add rule name="GlobalVillage API" dir=in action=allow protocol=TCP localport=3000-3004`
  验证方法:手机浏览器打开 `http://<电脑IP>:3002/health`,能看到 `{"ok":true...}` 即网络已通
- **Google 登录(手机 APP)**:需在 Google Cloud Console 给项目添加 Android 类型的 OAuth 客户端(与网页版共用的 Web 客户端并存),填入:
  - Package name:`com.example.global_village_app`
  - SHA-1(debug 签名,已与本包 dist/ 内 APK 匹配):`1C:54:4D:E4:41:14:AD:4C:9C:CE:B4:F3:9C:B6:BB:FE:DE:15:75:64`
  操作:console.cloud.google.com → APIs & Services → Credentials → Create Credentials → OAuth client ID → Android → 填入上面两项 → 保存(几分钟内生效,无需重装 APP)。邮箱密码登录不受影响
- **iOS**:需要 Mac + Apple 开发者账号,本包未包含
- **重新构建 APK**(改代码后):需 Flutter SDK + Android SDK,在**纯英文路径**下运行(中文路径会导致 AOT 编译失败):
  `flutter build apk --release --dart-define=GOOGLE_WEB_CLIENT_ID=848686154651-a5lrjn63ggqj83g5ob4bms7imqd6jkth.apps.googleusercontent.com`

## 使用流程

1. 打开应用,先**注册**账号(或使用 Google 登录,Google 登录需要配置 `GOOGLE_SIGNIN_SETUP.md` 中的客户端 ID)
2. 在 Chats 页面点击顶部搜索栏,输入对方的**邮箱 / 用户名 / 姓名**搜索注册用户
3. 点击 **Add** → **Send Request** 发送好友申请
4. 对方登录后,聊天页右上角**铃铛**会显示红色数字角标,点开即可 **Accept**(成为好友)或 **Decline**
5. 成为好友后出现在聊天列表,文字 / 语音消息全部存入 PostgreSQL 数据库,双方实时同步

## 语音 / 视频通话(1 对 1 + 群聊)

**1 对 1**:好友聊天头部电话 / 摄像头按钮发起;对方在线时弹出全屏来电,可接听 / 拒绝。

**群聊通话**:群聊头部同样有电话 / 摄像头按钮,任一群员可发起;其他在线群员收到全屏来电提醒,多人可同时加入(全连接 mesh,每人一条 P2P 连接)。通话进行中后进入群聊的成员会看到顶部「Ongoing call — tap to join」横幅,点击即可加入。群通话中支持静音、关闭摄像头、离开。

技术:WebRTC P2P(Google 公共 STUN),信令走 Chat API 的 WebSocket(`/ws`),复用登录 token 鉴权;1 对 1 仅好友可拨,群通话仅群成员可加入。通话页面支持来电脉冲、视频网格、计时。

## 群主与管理员

- **群主(Owner)**:建群者。可任命 / 撤销管理员、禁言 / 解除禁言、移除任何成员(群主不可被管理)。
- **管理员(Admin)**:可禁言 / 移除普通成员,不能动其他管理员和群主。
- **禁言**:被禁言的成员无法发送文字 / 语音消息(输入栏显示红色提示),可随时解除。
- **移除**:被移除的成员立即失去群访问(历史消息、通话均不可用),群主可再次邀请回来。

操作入口:群聊头部点头像(或菜单 → Group info)打开成员面板,成员行右侧 `⋮` 菜单提供 Promote / Demote / Mute / Unmute / Remove。徽章:金色 Owner、蓝色 Admin、红色话筒图标表示被禁言。

测试账号(均已互为好友,已建群 **Group Call Demo**,A 为群主):`calltest.a@test.local` / `calltest.b@test.local` / `calltest.c@test.local` / `calltest.d@test.local`(D 未入群),密码均为 `CallTest#2026`。用三个浏览器窗口分别登录 A、B、C 即可体验群通话与群管理。

## 服务与端口一览

| 服务 | 端口 | 说明 |
|---|---|---|
| Community API | http://localhost:3000 | 社区活动 |
| Community PostgreSQL | localhost:5433 | 数据卷 community-db-data |
| Auth API | http://localhost:3002 | 登录 / 注册 / 用户搜索 |
| Auth PostgreSQL | localhost:5434 | Auth Adminer 管理界面 http://localhost:8082 |
| Family API | http://localhost:3003 | 家庭模块 |
| Chat API | http://localhost:3004 | 好友申请 + 聊天消息 + 通话信令(`/ws`) |
| Chat PostgreSQL | localhost:5435 | 数据卷 chat-db-data |
| Flutter Web | http://localhost:7357 | 前端 |

## 停止服务

```powershell
docker compose -f docker-compose.yml stop
docker compose -f docker-compose.auth.yml stop
docker compose -f docker-compose.family.yml stop
docker compose -f docker-compose.chat.yml stop
```

> 不要随手运行 `docker compose down -v`,`-v` 会删除数据库数据。

## 其他文档

- `DATABASES_START_AND_INTEGRATION_GUIDE.md` — 数据库结构与集成说明
- `AUTH_DATABASE_SETUP.md` / `GOOGLE_SIGNIN_SETUP.md` — 登录与 Google 登录配置
- `数据库启动与连接操作说明.docx` — 数据库操作说明
