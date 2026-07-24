# HoneyBox Gitee CI

## 前置条件

在 Gitee 仓库启用 CI 前，请确认以下事项：

1. **Gitee Go 已开通**
   - 进入仓库 → "流水线" → "Gitee Go" → 按提示开启
   - 如果看不到入口，可能是仓库所属空间未开通 Gitee Go 企业版
   - 可联系 Gitee 客服或查看 [Gitee Go 文档](https://gitee.com/help/articles/4338)

2. **仓库已推送**
   - 确保 `.gitee/workflows/flutter-ci.yml` 已 push 到远端

## CI 检查内容

| 阶段 | 说明 |
|------|------|
| `analyze` | flutter analyze + flutter test (PR 和 push 都会触发) |
| `build-android` | 构建 debug APK，上传为 artifact |
| `lint` | dart format 格式检查 |

## 如何查看 CI 结果

1. 进入 Gitee 仓库页面
2. 点击顶部导航栏 **"流水线"** → 查看执行记录
3. 点击某条记录可查看详细的步骤日志

## 本地手动复现 CI

```bash
flutter pub get
flutter analyze
flutter test
dart format --set-exit-if-changed lib/ test/
flutter build apk --debug
```
