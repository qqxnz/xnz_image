# Changelog

## 0.1.12

- Made memory observer `init` / `dispose` idempotent.
- Unified monorepo package version to `0.1.12`.

## 0.1.11

- Added disk cache cleanup by last-hit time.
- Unified monorepo package version to `0.1.11`.

## 0.1.10 - 2026-04-28

- Removed disk cache cleanup and size limit logic.
- Improved disk cache touch-check behavior with a fixed interval on cache hits.
- Unified monorepo package version to `0.1.10`.

## 0.1.9 - 2026-04-27

- Increased default image downloader timeout values to improve network robustness.
- Unified monorepo package version to `0.1.9`.

## 0.1.8

- Unified monorepo package version to `0.1.8`.

## 0.1.7

- Unified monorepo package version to `0.1.7`.

## 0.1.6

- Set downloader global connection timeout to 5 seconds via `Dio(BaseOptions)`.
- Removed per-task `connectTimeout` argument from `XNZImageDownloaderTask`.

## 0.1.5

- Renamed cache memory observer API to `XNZImageMemoryObserver`.
- Renamed log API to `XNZImageLogs`.

## 0.1.4

- Unified monorepo release version.
- Prepared package metadata for pub.dev publishing.
