# xnz_image 发版流程执行文档

本文档用于规范 `xnz_image` Monorepo 的发版流程，覆盖版本更新、文档同步、pub.dev 发布、Git 收尾，以及“发版后恢复 examples 本地目录引用”。

## 0. 约定与目标

- 本文档默认一次统一发版版本号：`<version>`（例如 `0.1.9`）。
- 发布阶段允许临时改动引用用于验证，但发布完成后必须恢复开发态（本地 `path` 引用）。
- 所有命令默认在仓库根目录执行：`xnz_image/`。

## 1. 发布前检查

1. 确认分支与工作区干净：
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

4. 确认 examples 当前为本地目录引用（开发态）：
```bash
rg -n "path:\\s+\\.\\./\\.\\.|path:\\s+\\.\\./\\.\\./packages" examples/*/pubspec.yaml
```

## 2. 版本与文档同步（必须）

每次发版都要同时更新以下内容：

1. 版本号：
- 根包：`pubspec.yaml`
- 子包：`packages/*/pubspec.yaml`

2. 变更日志：
- 根包：`CHANGELOG.md`
- 子包：`packages/*/CHANGELOG.md`

3. README 安装示例版本号：
- 根包：`README.md`
- 子包：`packages/*/README.md`
- 将示例中的依赖版本更新为本次发版版本，避免文档与 pub.dev 不一致。

快速核对 README：
```bash
rg -n "xnz_image(_core|_svg|_avif)?:\\s*\\^" README.md packages/*/README.md
```

## 3. 发布顺序（Monorepo）

按依赖关系发布：

1. `packages/xnz_image_core`
2. 根包 `xnz_image`
3. `packages/xnz_image_svg`
4. `packages/xnz_image_avif`

说明：
- `xnz_image` 依赖 `xnz_image_core`
- `xnz_image_svg` / `xnz_image_avif` 依赖 `xnz_image`

## 4. 发布命令（每个包都先 dry-run）

在目标包目录执行：

```bash
PUB_HOSTED_URL=https://pub.dev \
FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com \
flutter pub publish --dry-run

PUB_HOSTED_URL=https://pub.dev \
FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com \
flutter pub publish --force
```

## 5. 索引同步检查（重要）

上一个包发布成功后，等待 pub.dev 索引可见，再发布下一个依赖包。

示例（发布 `xnz_image_core <version>` 后）：
```bash
curl -s https://pub.dev/api/packages/xnz_image_core | rg "\"version\":\"<version>\""
```

若本地提示 `doesn't match any versions`，通常是索引延迟，等待后重试。

## 6. 发版完成后：恢复 examples 本地目录引用（必须）

如果你在发版过程中把 `examples/*/pubspec.yaml` 改成了版本依赖（`^<version>`）做验证，发版完成后必须恢复为 `path` 本地引用，避免影响后续仓库联调。

应恢复为以下形态：

1. `examples/example_bitmap/pubspec.yaml`
```yaml
dependencies:
  xnz_image:
    path: ../../
```

2. `examples/example_bitmap_svg/pubspec.yaml`
```yaml
dependencies:
  xnz_image:
    path: ../../
  xnz_image_svg:
    path: ../../packages/xnz_image_svg

dependency_overrides:
  xnz_image:
    path: ../../
```

3. `examples/example_bitmap_avif/pubspec.yaml`
```yaml
dependencies:
  xnz_image:
    path: ../../
  xnz_image_avif:
    path: ../../packages/xnz_image_avif

dependency_overrides:
  xnz_image:
    path: ../../
```

4. `examples/example_bitmap_svg_avif/pubspec.yaml`
```yaml
dependencies:
  xnz_image:
    path: ../../
  xnz_image_svg:
    path: ../../packages/xnz_image_svg
  xnz_image_avif:
    path: ../../packages/xnz_image_avif

dependency_overrides:
  xnz_image:
    path: ../../
```

恢复后执行核对：

```bash
rg -n "xnz_image(_svg|_avif)?:\\s*\\^[0-9]" examples/*/pubspec.yaml
```

期望结果：无输出（表示不再有版本引用）。

可选：逐个 example 执行 `flutter pub get`，确认依赖解析正常。

## 7. Git 收尾（commit / push / tag）

1. 提交发版及回切变更：
```bash
git add CHANGELOG.md README.md pubspec.yaml pubspec.lock \
  packages/*/CHANGELOG.md packages/*/README.md packages/*/pubspec.yaml packages/*/pubspec.lock \
  examples/*/pubspec.yaml
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

## 8. 常见问题

1. `doesn't match any versions`
- 常见于上游包刚发布，索引还未同步。
- 处理：等待几分钟并重试，或先用 pub API 确认版本是否可见。

2. dry-run 警告
- 如 `.gitignore`/目录命名等提示，通常不阻断发布。
- 建议后续逐步清理，提升包质量评分。

3. 忘记恢复 examples 本地引用
- 症状：examples 依赖指向 pub 版本，联调无法及时验证本地改动。
- 处理：按第 6 节恢复 `path`，再执行 `flutter pub get`。
