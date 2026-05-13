# xnz_image 磁盘缓存改造完整方案（SHA-256 + `.meta`）

## 1. 目标

将当前磁盘缓存从“仅依赖 cacheKey 文件名 + 文件修改时间”升级为“内容文件 + 元数据文件（`.meta`）”双文件模型，满足以下要求：

1. 磁盘文件名使用 `SHA-256`（全长）+ 小写 hex（或 base32）。
2. 文件名格式为 `<hash>[.<ext>]`，无扩展名则不追加。
3. 为每个缓存内容文件写入同名 `.meta` 文件，记录原始 key 校验、原始 URL、headers 等。
4. 缓存命中判断先读 `.meta` 做校验，再读取内容文件。
5. 缓存过期逻辑统一使用 `.meta` 中的时间字段。
6. 在仓库内置纯 Dart SHA-256 实现，不引入第三方依赖。

## 2. 当前实现现状（简述）

1. 磁盘缓存文件名当前直接使用 `request.cacheKey`。
2. `has/get` 仅判断文件存在与可读，不校验请求上下文。
3. `clearUnusedSince` 依赖文件系统 `modified` 时间。
4. `cacheKey` 哈希当前为 FNV（IO 64-bit / Web 32-bit）。
5. 无独立 meta 文件、无内置 TTL/expireAt 字段。

## 3. 总体设计

### 3.1 缓存条目结构

每条缓存由两个文件组成：

1. 数据文件：`<contentHash>[.<ext>]`
2. 元数据文件：`<contentHash>[.<ext>].meta`

其中：

1. `contentHash` = 对“缓存键源串”做 SHA-256（小写 hex 64 字符）。
2. `ext` 从 URL 推断（如 `png`、`jpg`、`webp`）；若无法推断则不加后缀。

### 3.2 缓存键与哈希

保留现有语义：

1. `urlOnly`：缓存键源串使用规范化 URL。
2. `urlAndHeaders`：缓存键源串使用 `requestKey`（URL + 规范化 headers 摘要/串）。

但哈希算法统一改为 SHA-256：

1. `cacheKey` 输出固定 64 位小写 hex。
2. Web/IO 一致，不再分 32/64 位 FNV。

### 3.3 `.meta` 结构定义（建议）

建议 JSON 字段如下（v1）：

```json
{
  "schemaVersion": 1,
  "hashAlgo": "sha256-hex",
  "cacheKey": "64hex...",
  "cacheKeyStrategy": "urlOnly",
  "keySourceChecksum": "64hex...",
  "originalUrl": "https://example.com/a.png",
  "requestHeaders": {
    "authorization": "Bearer xxx",
    "x-tenant": "foo"
  },
  "createdAtMs": 1760000000000,
  "lastAccessAtMs": 1760000000000,
  "expireAtMs": null,
  "contentLength": 12345,
  "ext": "png"
}
```

字段说明：

1. `keySourceChecksum`：对“缓存键源串”再做一次 SHA-256，用于“原始 key 校验”。
2. `requestHeaders`：保存规范化 headers（小写 key、稳定顺序）。
3. `expireAtMs`：可空；空表示仅按 `clearUnusedSince` 的访问时效清理。
4. `lastAccessAtMs`：命中读取后按节流策略更新。
5. `contentLength`：读取时可用于快速一致性校验。

## 4. 关键流程

### 4.1 写入流程（set）

1. 根据 `XNZUrlRequest` 计算 `cacheKey`（SHA-256）。
2. 推断扩展名 `ext`，生成数据文件路径和 meta 路径。
3. 原子写入数据文件（建议临时文件 + rename）。
4. 生成并写入 `.meta`（包含 key 校验、url、headers、时间、大小等）。
5. 失败处理：任一步失败时清理临时文件，避免半写入。

### 4.2 命中检测（has）

1. 先查 `.meta` 是否存在。
2. 读 meta 并校验：
   1. `schemaVersion/hashAlgo` 合法。
   2. `cacheKey`、`keySourceChecksum` 与当前请求匹配。
   3. `originalUrl` 与请求规范化 URL 一致。
   4. `cacheKeyStrategy` 与请求一致。
   5. `expireAtMs` 未过期。
3. 再检查数据文件存在且可读。
4. 任一失败都返回 miss，并触发数据+meta 清理（best effort）。

### 4.3 读取流程（get）

1. 执行与 `has` 相同的 meta 校验。
2. 读取数据文件字节。
3. 校验 `contentLength`（若不符则视为损坏并清理）。
4. 更新 `lastAccessAtMs`（节流更新，避免高频 IO）。
5. 返回字节。

### 4.4 清理流程

#### remove

1. 删除数据文件。
2. 删除同名 `.meta`。

#### clearAll

1. 清空缓存目录（现有逻辑可复用）。

#### clearUnusedSince

1. 遍历 `.meta` 文件而不是数据文件。
2. 使用 `lastAccessAtMs` 与 `maxUnusedDuration` 判断是否过期未使用。
3. 删除对应数据文件 + meta 文件。
4. 若 meta 损坏或孤儿文件，按策略清理并计数。

## 5. 纯 Dart SHA-256 设计

新增文件建议：

1. `packages/xnz_image_core/lib/src/support/xnz_sha256.dart`

提供 API 建议：

1. `String xnzSha256Hex(List<int> bytes)`
2. `String xnzSha256HexOfString(String text)`（UTF-8）

实现要求：

1. 不依赖 `crypto` 或其他第三方库。
2. 完整实现 SHA-256（padding、消息扩展、64 rounds、常量 K）。
3. 输出固定 64 位小写 hex。

测试向量（至少）：

1. `""` -> `e3b0c442...b855`
2. `"abc"` -> `ba7816bf...15ad`
3. `"hello world"` 标准已知值

## 6. 代码改造点（按模块）

### 6.1 `support/xnz_cache_key_*`

1. 替换 FNV 实现为 SHA-256。
2. 保持对外 API 名称 `xnzBuildCacheKey` 不变，减少上层改动。

### 6.2 `support/xnz_url_request.dart`

1. 保持 `cacheKeyStrategy` 语义不变。
2. 增加可复用方法导出“缓存键源串”（供 meta 校验使用），避免重复拼接逻辑分叉。

### 6.3 `xnz_cache_disk_io.dart`

1. `set/get/has/remove` 入参改为 `XNZUrlRequest`（建议）或新增重载。
2. 新增 meta 读写、校验、过期判断、孤儿清理逻辑。
3. `clearUnusedSince` 改为基于 meta 的 `lastAccessAtMs`。
4. 保留 `_touchInterval` 思路，但更新对象改为 meta 的 `lastAccessAtMs`。

### 6.4 `xnz_cache_manager.dart`

1. 所有磁盘缓存调用从 `cacheKey` 传递改为传 `request`。
2. 内存缓存仍可继续用 `cacheKey` 字符串做键。

### 6.5 README 文档

1. 更新“FNV”相关描述为“SHA-256”。
2. 新增 `.meta` 校验与过期机制说明。
3. 明确 `urlOnly/urlAndHeaders` 对缓存隔离的影响。

## 7. 兼容与迁移策略

### 7.1 旧缓存兼容

旧版本仅有数据文件、无 meta：

1. 新版本读取时找不到 `.meta` -> 视为 miss。
2. 可执行惰性清理：在 miss 分支尝试删除旧文件（best effort）。
3. 不做启动期全量迁移，降低冷启动和实现复杂度。

### 7.2 行为变化

1. 升级后首次请求会重建一批缓存（预期行为）。
2. 命中可靠性提高，缓存污染风险降低。

## 8. 风险与防护

1. 风险：header 直接写入 meta 可能含敏感信息。
   1. 选项 A：保存原文（满足“写入 header”等需求）。
   2. 选项 B：保存脱敏/摘要并增加 `headerDigest`（更安全）。
   3. 建议：默认原文 + 提供可配置脱敏策略（后续增强）。
2. 风险：写入中断导致 data/meta 不一致。
   1. 使用临时文件 + rename。
   2. 读路径发现不一致即清理。
3. 风险：高频读导致 meta 写放大。
   1. 对 `lastAccessAtMs` 做节流（如 10 分钟）。

### 8.1 `lastAccessAtMs` 节流更新规范

建议新增常量：

1. `touchInterval = Duration(minutes: 10)`

读取命中时执行：

1. 设 `nowMs = DateTime.now().millisecondsSinceEpoch`。
2. 读取 meta 中 `lastAccessAtMs`（为空则视为 0）。
3. 若 `nowMs - lastAccessAtMs < touchInterval.inMilliseconds`：
   1. 跳过写 meta（只返回数据）。
4. 否则：
   1. 将 `lastAccessAtMs` 更新为 `nowMs`。
   2. 通过临时文件 + rename 覆盖写 `meta`（沿用原子写协议）。

补充约束：

1. `has()` 不更新 `lastAccessAtMs`，仅 `get()` 命中更新，避免探测型调用放大写入。
2. 节流写失败不影响本次读返回；仅记录日志，避免把可读缓存变成失败请求。
3. 若条目已过期（`expireAtMs <= nowMs`），直接按 miss 处理，不执行 touch。

## 9. 测试计划

### 9.1 单元测试

1. SHA-256 标准向量校验。
2. `urlOnly` 同 URL 不同 header 仍命中同一 key。
3. `urlAndHeaders` 不同 header 命中不同 key。
4. 无扩展名 URL 文件名不带 `.`。
5. 有扩展名 URL 文件名带 `.ext` 且小写。
6. meta 缺失/损坏/不匹配时判 miss 并清理。
7. `expireAtMs` 过期判 miss。
8. `clearUnusedSince` 基于 `lastAccessAtMs` 生效。

### 9.2 集成验证

1. `XNZNetworkImageProvider` 首次下载后产生 data + `.meta`。
2. 二次加载命中磁盘并写回内存。
3. 强制删 data 或删 meta 时都能自愈重下。
4. 读写异常时日志事件正确。

## 10. 执行清单（可勾选）

## Phase A - 基础能力

- [ ] A1. 新增 `xnz_sha256.dart` 纯 Dart 实现（无第三方依赖）
- [ ] A2. 新增 SHA-256 单测（空串、abc、hello world）
- [ ] A3. 将 `xnzBuildCacheKey` 从 FNV 切换到 SHA-256

## Phase B - 元数据模型

- [ ] B1. 新增 `DiskCacheMeta` 数据结构与 JSON 编解码
- [ ] B2. 定义 `schemaVersion=1` 与字段约束
- [ ] B3. 增加 keySource 计算与 `keySourceChecksum` 工具方法

## Phase C - 磁盘缓存链路改造

- [ ] C1. `XNZDiskCache.set` 改为写 data + `.meta`
- [ ] C2. `XNZDiskCache.has` 改为先读 `.meta` 校验
- [ ] C3. `XNZDiskCache.get` 改为 meta 校验后读 data 并更新 `lastAccessAtMs`
- [ ] C4. `XNZDiskCache.remove` 同时删除 data/meta
- [ ] C5. `clearUnusedSince` 改为遍历 `.meta` 并按 `lastAccessAtMs` 清理
- [ ] C6. 增加孤儿文件（仅 data / 仅 meta）清理逻辑

## Phase D - 管理层适配

- [ ] D1. `XNZCacheManager` 磁盘调用改为传 `XNZUrlRequest`
- [ ] D2. 保持内存缓存键继续使用 `request.cacheKey`
- [ ] D3. 下载链路回归（`XNZImageDownloader` / `XNZNetworkImageProvider`）

## Phase E - 文档与回归

- [ ] E1. 更新 README/README.zh-CN 的哈希算法与缓存机制描述
- [ ] E2. 新增 meta 校验与过期策略说明
- [ ] E3. 增加回归测试（策略隔离、过期、损坏恢复、扩展名策略）
- [ ] E4. 本地跑测试并记录结果

## 11. 验收标准（Done Definition）

1. 磁盘文件名符合 `<sha256-hex>[.<ext>]`。
2. 每个缓存条目都存在 `.meta` 且字段完整。
3. `has/get` 在命中前必经 meta 校验。
4. 过期与未使用清理仅依赖 meta 时间字段（不依赖文件 mtime）。
5. 无新增第三方依赖，SHA-256 为仓库内纯 Dart 实现。
6. 既有公开 API 行为保持兼容（除缓存重建这一预期变化）。

## 12. 建议实施顺序（低风险）

1. 先落地 SHA-256 与单测（不改缓存流程）。
2. 再引入 meta 模型与新读写流程（IO 平台）。
3. 最后收口 `CacheManager` 调用、文档与回归测试。

## 13. 原子写入协议（data/meta 一致性）

目标：任意时刻崩溃/中断后，缓存目录里只能出现“完整旧版本”或“完整新版本”，避免半写状态被误判为命中。

### 13.1 写入步骤（推荐顺序）

1. 设目标路径：
   1. `dataPath = <hash>[.<ext>]`
   2. `metaPath = <hash>[.<ext>].meta`
2. 生成临时路径（同目录）：
   1. `dataTmp = dataPath + .tmp.<pid>.<ts>`
   2. `metaTmp = metaPath + .tmp.<pid>.<ts>`
3. 写 `dataTmp` 并 `flush: true`。
4. 构建 meta（`contentLength`/checksum/时间戳等），写 `metaTmp` 并 `flush: true`。
5. `rename(dataTmp -> dataPath)`。
6. `rename(metaTmp -> metaPath)`。
7. 最终以 `metaPath` 存在作为“条目可见”的提交标志。

### 13.2 读取约束（与写入协议配套）

1. 读取先看 `metaPath`，没有 meta 直接 miss。
2. 读 meta 后检查 `dataPath` 是否存在且长度匹配。
3. 任一失败即删残留（data/meta/tmp）并 miss。

### 13.3 清理规则

1. 启动或定时清理时，删除超过阈值（如 1 小时）的 `*.tmp.*` 文件。
2. 对“仅 data 无 meta”或“仅 meta 无 data”条目执行 best-effort 删除。

### 13.4 并发写同 key（可选增强）

1. 进程内：对同一 `cacheKey` 加互斥锁（`Map<String, Future<void>>` 串行化）。
2. 即便无锁，协议也能保证最终状态可恢复；加锁可减少重复写与抖动。
