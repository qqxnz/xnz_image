# xnz_image 发版流程执行文档

本文档用于规范 `xnz_image` Monorepo 的发版流程，覆盖版本更新、文档同步、pub.dev 发布、Git 提交与打 Tag。

## 1. 发布前检查

1. 确认分支与工作区：
```bash
git status --short --branch
```

2. 确认版本现状：
```bash
rg -n "^version:\\s*" pubspec.yaml packages/*/pubspec.yaml
```

3. 确认 pub.dev 登录状态：
```bash
dart pub token list
```

## 2. 版本与文档同步（必须）

每次发版都要同时更新以下文件：

1. 版本号：
   - 根包：`pubspec.yaml`
   - 子包：`packages/*/pubspec.yaml`

2. 变更日志：
   - 根包：`CHANGELOG.md`
   - 子包：`packages/*/CHANGELOG.md`

3. README 版本号（重点）：
   - 根包：`README.md`
   - 子包：`packages/*/README.md`
   - 将安装示例中的版本号同步为本次发版版本，避免文档与实际包版本不一致。

可用以下命令快速核对 README 里的版本号：
```bash
rg -n "\\^0\\.1\\.|dependencies:" README.md packages/*/README.md
```

## 3. 发布顺序（Monorepo）

按当前依赖关系，推荐顺序如下：

1. `packages/xnz_image_core`
2. 根包 `xnz_image`
3. `packages/xnz_image_svg`
4. `packages/xnz_image_avif`

说明：
- `xnz_image` 依赖 `xnz_image_core`
- `xnz_image_svg` / `xnz_image_avif` 依赖 `xnz_image`

## 4. 发布命令（每个包都先 dry-run）

建议统一使用官方源环境变量：

```bash
PUB_HOSTED_URL=https://pub.dev \
FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com \
flutter pub publish --dry-run

PUB_HOSTED_URL=https://pub.dev \
FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com \
flutter pub publish --force
```

## 5. 索引同步检查（重要）

上一个包发布成功后，可能需要等待 pub.dev 索引同步，再发布下一个依赖它的包。

例如发布完 `xnz_image_core 0.1.7` 后：
```bash
curl -s https://pub.dev/api/packages/xnz_image_core | rg "\"version\":\"0.1.7\""
```

如果本地 `pub` 仍提示 `doesn't match any versions`，等待片刻后重试。

## 6. Git 收尾（commit / push / tag）

1. 提交发版变更：
```bash
git add CHANGELOG.md README.md pubspec.yaml pubspec.lock \
  packages/*/CHANGELOG.md packages/*/README.md packages/*/pubspec.yaml packages/*/pubspec.lock
git commit -m "chore(release): publish xnz_image monorepo <version>"
```

2. 推送主分支：
```bash
git push origin main
```

3. 打 Tag 并推送：
```bash
git tag v<version>
git push origin v<version>
```

## 7. 常见问题

1. `doesn't match any versions`
   - 常见于上游包刚发布，索引还未同步。
   - 处理：等待几分钟并重试；或先用 API 确认版本是否可见。

2. dry-run 警告
   - 如 `.gitignore`/目录命名等提示，通常不阻断发布。
   - 建议逐步清理，提升包质量评分。
