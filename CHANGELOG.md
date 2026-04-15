# Changelog

## 0.1.7

- Added `XNZAnimatedImage` controllable animated-image widget with pause/resume/replay/loop/completion hooks and timeline sync.
- Added animated demos in examples and improved static-image behavior when using animated widget.
- Unified monorepo package version to `0.1.7`.

## 0.1.6

- Removed `connectTimeout` from `XNZNetworkImage` and unified connection-timeout behavior in core downloader.

## 0.1.5

- Added SVG support for widget components: `XNZNetworkImage`, `XNZMemoryImage`, `XNZFileImage`, and `XNZAssetImage`.

## 0.1.4

- Unified version across `xnz_image`, `xnz_image_core`, `xnz_image_svg`, and `xnz_image_avif`.
- Switched internal package dependencies to hosted versions for pub.dev publishing.

## 0.1.3

- Added new features.

## 0.1.2

- Updated `homepage` and `repository` to `https://github.com/qqxnz/xnz_image.git`.

## 0.1.1

- Added real GitHub metadata in `pubspec.yaml` (`homepage` and `repository`).
- Declared supported platforms (`android`, `ios`, `linux`, `macos`, `windows`) for pub.dev display.

## 0.1.0

- Initial release of `xnz_image`.
- Added network, memory, and file image rendering widgets/providers.
- Included AVIF decoding support and integrated memory/disk cache management.
