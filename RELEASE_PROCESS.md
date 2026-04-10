# xnz_image 发版流程执行文档

本文档用于规范 `xnz_image` 的发布流程，覆盖版本号更新、变更日志维护、发布到 pub.dev、远程仓库推送与打 Tag。

## 1. 发布前准备

1. 确认当前分支与工作区状态
```bash
git status --short --branch
```

2. 确认当前版本号
```bash
rg -n "^version:\\s*" pubspec.yaml packages/*/pubspec.yaml
```

3. 确保登录 pub.dev（仅首次需要）
```bash
dart pub token list
```

## 2. 版本号与变更日志

1. 更新主包版本号：`pubspec.yaml`
2. 更新子包版本号（如有）：`packages/*/pubspec.yaml`
3. 更新变更日志：
   - 主包：`CHANGELOG.md`
   - 子包：`packages/*/CHANGELOG.md`

示例（将 `0.1.4` 升级到 `0.1.5`）：
- `pubspec.yaml`：`version: 0.1.5`
- `packages/xnz_image_core/pubspec.yaml`：`version: 0.1.5`
- `CHANGELOG.md` 增加 `## 0.1.5`

## 3. 发布顺序（Monorepo）

如果主包依赖子包的新版本，必须先发布子包，再发布主包。

推荐顺序：
1. `packages/xnz_image_core`
2. `packages/xnz_image_svg`（如有版本变更）
3. `packages/xnz_image_avif`（如有版本变更）
4. 根包 `xnz_image`

## 4. 发布命令

先 dry-run，再正式发布：

```bash
# 子包示例
cd packages/xnz_image_core
flutter pub publish --dry-run
flutter pub publish --force

# 根包示例（建议显式使用官方源）
cd /path/to/xnz_image
PUB_HOSTED_URL=https://pub.dev FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com flutter pub publish --dry-run
PUB_HOSTED_URL=https://pub.dev FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com flutter pub publish --force
```

## 5. Git 提交、远程 push、打 Tag

1. 提交版本变更
```bash
git add CHANGELOG.md pubspec.yaml pubspec.lock packages/xnz_image_core/pubspec.yaml packages/xnz_image_core/CHANGELOG.md
git commit -m "chore(release): publish xnz_image 0.1.5 and xnz_image_core 0.1.5"
```

2. 推送主分支
```bash
git push origin main
```

3. 打版本 Tag 并推送
```bash
git tag v0.1.5
git push origin v0.1.5
```

## 6. 执行示例（2026-04-10）

- 发布版本：
  - `xnz_image_core 0.1.5`
  - `xnz_image 0.1.5`
- 提交：
  - commit: `00f0824`
  - message: `chore(release): publish xnz_image 0.1.5 and xnz_image_core 0.1.5`
- 远程推送：
  - `main -> origin/main` 成功
- Tag：
  - `v0.1.5` 已创建并推送到远程

## 7. 常见问题

1. **主包无法解析到子包新版本**
   - 现象：`doesn't match any versions`
   - 处理：
     - 等待 pub.dev 索引同步（通常数分钟）
     - 显式指定官方源：
       - `PUB_HOSTED_URL=https://pub.dev`
       - `FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com`

2. **dry-run 警告（非阻断）**
   - 如 `.gitignore` 文件提示、`examples` 命名建议等，通常不阻断发布。
   - 建议后续版本逐步清理以提升包质量评分。
