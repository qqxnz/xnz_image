# Changelog

## Unreleased

## 0.2.2

- Unified monorepo package version to `0.2.2`.

## 0.2.1

- Restored and extended structured observability logs in image registry/cache manager/cache logs flows.
- Unified monorepo package version to `0.2.1`.

## 0.2.0

- Changed cache-key hashing by platform: Web keeps FNV-1a 32-bit behavior, while IO platforms (Android/iOS/macOS/Linux/Windows) now use FNV-1a 64-bit to reduce cache-collision risk.
- Unified cache-key strategy behavior across web and IO loaders/downloader paths.
- Unified monorepo package version to `0.2.0`.

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
