# Changelog

## Unreleased

## 0.2.5

- Added disk cache `ttl` / `expireAtMs` API support and cleanup flow for expired entries.
- Refined component implementation docs and removed duplicated README content.
- Synced monorepo package versions and dependency examples to `0.2.5`.

## 0.2.4

- Migrated disk cache keying to SHA-256 plus metadata and introduced a TTL evolution plan for cache lifecycle management.
- Synced monorepo package versions and dependency examples to `0.2.4`.

## 0.2.3

- Added success/failure log filtering support to improve observability signal quality.
- Synced monorepo package versions and dependency examples to `0.2.3`.

## 0.2.2

- Added framework-level cache hit/miss observability logs for memory-image provider flow.
- Synced monorepo package versions and dependency examples to `0.2.2`.

## 0.2.1

- Restored and extended structured runtime observability across image providers, decode helpers, and stream completer flows.
- Improved network/file/memory/asset image pipeline diagnostics and synced related docs.
- Synced monorepo package versions and dependency examples to `0.2.1`.

## 0.2.0

- Changed cache-key hashing by platform: Web keeps FNV-1a 32-bit behavior, while IO platforms (Android/iOS/macOS/Linux/Windows) now use FNV-1a 64-bit to reduce cache-collision risk.
- Refactored `XNZAnimatedImage` internals into `lib/src/animated/` submodules to reduce single-file responsibility and improve maintainability.
- Optimized animated-memory cache key generation by caching bytes fingerprints per byte-array identity.
- Unified resolve/render helper flow across `XNZAssetImage`, `XNZMemoryImage`, `XNZFileImage`, and `XNZNetworkImage` to reduce duplicated widget template logic.
- Unified IO-side animated network bytes loading with the downloader/cache pipeline (`XNZUrlRequest` + `XNZImageDownloader` + `XNZCacheManager`) for consistent cache-key strategy behavior.
- Replaced AVIF codec key generation based on object hash with process-local monotonic keys to reduce collision risk in native decoder mapping.
- Added guardrails for AVIF async frame decode failure paths and download-completer race conditions.
- Unified runtime logs to structured format: `[module][action][key=value,...]` via `XNZImageLogs.event(...)` and migrated core/provider/downloader/cache logs.
- Added regression tests for IO unified cache path loading and AVIF codec key monotonicity.
- Updated README/README.zh-CN and audit documentation to reflect P2 issue fixes.
- Synced monorepo package versions and dependency examples to `0.2.0`.

## 0.1.12

- Improved memory observer init/dispose idempotency and animated image cache eviction behavior.
- Synced README dependency examples and monorepo package versions to `0.1.12`.

## 0.1.11

- Synced README dependency examples and monorepo package versions to `0.1.11`.

## 0.1.10 - 2026-04-28

- Added bilingual README content, API dartdoc improvements, and pub example updates.
- Synced README dependency examples and monorepo package versions to `0.1.10`.

## 0.1.9 - 2026-04-27

- Unified image decode validation across providers for more consistent behavior.
- Synced README dependency examples and monorepo package versions to `0.1.9`.

## 0.1.8

- Improved release process documentation and clarified publish order/checklist.
- Synced README dependency versions to `0.1.8`.

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
