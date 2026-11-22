# Global Village 更新记录（2026-11-10）

本次仅涉及 Flutter 个人资料页（Profile）及相关共享状态，未修改后端接口、数据库结构或公网部署。

## 数据正确性

- `profileFromAuthUser` 改为按字段是否存在做 fallback：服务器明确返回空字符串、空数组或 `null` 时使用空值，不再用本地旧值覆盖。
  手机号、地址、社区、生日、兴趣标签、自定义分类现在都能真正清空。
- 移除个人页的演示资料。`currentProfile` 初始值为 `emptyProfile()`，登录或加载成功前不再显示假姓名、假邮箱。
- 个人页增加加载中、加载失败和重试三种状态；加载未成功时不允许保存，避免把占位数据写回数据库。
- Email 在编辑态改为只读，并提示它是登录账号的一部分。开放修改需要后端 email 更新接口与验证流程，本次未做。
- 保存逻辑改为「服务器成功后再更新本地」：失败时保留编辑态和用户输入并显示真实错误，成功后用服务器返回值刷新界面。
- 修掉旧的单 `interest` 字段（老账号）在解析后被 fallback 覆盖、导致兴趣为空的问题。
- 6 个 `TextEditingController` 改为 `initState` 创建一次，后续只改 `.text`，不再重复创建造成泄漏。

## 状态与交互

- `_MyProfileTab` 与两个匹配 Tab 增加 `AutomaticKeepAliveClientMixin`；`HomePage` 改为惰性 `IndexedStack`，访问过的底部 Tab 保持挂载。切换 Tab 或进入修改密码/密保页面再返回，未保存的编辑不会丢失。
- 登出增加二次确认。`AuthService.clearSession()` 同时重置 `currentProfile` 和 `ChatSessionsState`，避免下一个账号看到上一个账号的资料和聊天摘要；并修复 `main_placeholder_page.dart` 登出未清理会话的问题。
- 保存前做本地校验：姓名非空、用户名 3–30 位字母/数字/下划线/点、电话格式；生日改为可选。
- 保存期间按钮显示 loading 且不可重复提交。
- 自定义兴趣输入改为两行布局（输入框一行，分类下拉与 Add 按钮一行），窄屏不再溢出。
- 从 Add Friend 页面返回、重新进入匹配 Tab 时刷新好友/请求状态。

## 匹配 Tab

- 候选用户改为首次进入匹配 Tab 时才请求，只看个人资料时不再预拉列表。
- 过滤掉匹配度 0% 的用户，并按「无候选人 / 无共同兴趣 / 无推荐」区分空态文案。
- 匹配结果按 `profile` 与 `candidates` 身份缓存，数据不变时不重复计算。
- 个人头像和匹配列表头像支持 `googlePhotoUrl`，加载失败回退姓名首字母。

## 结构与样式

- 匹配相关组件拆分到 `lib/pages/profile_match_widgets.dart`，通过 `part` 保持私有类；`profile_page.dart` 由约 1458 行降至约 1072 行。
- `AppTheme` 新增 `hint`、`divider`，个人页硬编码颜色改用主题 token。
- 新增测试：
  - `test/profile_model_test.dart`：空字段清除、缺失字段 fallback、Google 头像、legacy 兴趣、无生日请求体、登出重置。
  - `test/profile_page_state_test.dart`：离线禁止保存、Tab 切换保留编辑、登出二次确认。

## 验证（Flutter 3.44.6 / Dart 3.12.2）

- `flutter analyze`：0 error、0 warning、0 info。
- `flutter test`：105 项全部通过（含此前记录为失败的 8 项 UI 测试）。
- `flutter build web --release`：成功，产物在 `build/web`。

## 仍未完成

- 修改邮箱：需要后端 `PATCH /auth/me` 支持 email、唯一性校验和邮箱验证流程。
- 匹配候选人分页：目前仍是一次最多 200 个。
- 本地头像上传：目前仅支持 Google 头像 URL。
- 真实服务手工回归：离线提示、清空字段保存、换账号隔离、匹配 Tab 懒加载需要在连接 auth-server 的环境再点一遍。
