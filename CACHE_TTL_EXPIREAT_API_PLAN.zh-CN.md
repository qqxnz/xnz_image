# xnz_image TTL / expireAtMs API 设计方案与执行清单

## 1. 目标

在现有 data+meta 磁盘缓存模型上，增加可配置 TTL 能力，使缓存写入时自动生成 `expireAtMs`，并保持与现有行为兼容：

1. 不配置 TTL 时，行为与当前一致（`expireAtMs = null`）。
2. 配置 TTL 后，写入 meta 时自动落 `expireAtMs`。
3. 读取命中和清理逻辑继续统一依赖 meta（已具备）。

## 2. 设计原则

1. 默认不破坏：现有调用点无需改动。
2. 最小侵入：优先在 `XNZCacheManager` 层新增配置，向下传给 `XNZDiskCache`。
3. 分层清晰：TTL 决策在管理层；磁盘层只负责写入与校验。
4. 可渐进扩展：后续可加“按域名/路径/header 条件 TTL”。

## 3. API 方案（建议）

## 3.1 全局默认 TTL（第一阶段）

在 `XNZCacheManager` 增加：

1. `Duration? diskCacheDefaultTtl`（默认 `null`）
2. `void setDiskCacheDefaultTtl(Duration? ttl)`

语义：

1. `null`：不设绝对过期时间（当前行为）。
2. `ttl <= Duration.zero`：视为立即过期（建议内部归一为 `Duration.zero`）。
3. `ttl > 0`：`expireAtMs = now + ttl`。

## 3.2 单次写入覆盖 TTL（第二阶段）

在 `setCache` 增加可选参数：

1. `Future<void> setCache(XNZUrlRequest request, Uint8List data, {Duration? ttlOverride})`

优先级：

1. `ttlOverride`（若传入）
2. `diskCacheDefaultTtl`
3. `null`

## 3.3 读取时是否“续期”（第三阶段，可选）

增加策略开关（默认关闭）：

1. `bool refreshExpireAtOnRead = false`

当开启且命中时：

1. 使用原 TTL 时长重新计算 `expireAtMs`
2. 与 `lastAccessAtMs` 一起节流更新（避免写放大）

备注：此项会改变语义（absolute expiration -> sliding expiration），建议后置。

## 4. 代码落点

1. `packages/xnz_image_core/lib/src/xnz_cache_manager.dart`
   1. 新增 TTL 配置字段与 setter
   2. `setCache` 计算 `expireAtMs`
2. `packages/xnz_image_core/lib/src/xnz_cache_disk_io.dart`
   1. `set(...)` 增加 `int? expireAtMs` 入参
   2. 写 meta 使用传入值
3. `packages/xnz_image_core/lib/src/xnz_cache_disk_web.dart`
   1. 同步签名（stub 保持 no-op）
4. README 文档
   1. 新增 TTL 配置示例
   2. 说明默认行为与兼容性

## 5. 行为边界与约定

1. 旧缓存 meta 无 `expireAtMs`：按 `null` 处理。
2. `expireAtMs` 到期：
   1. `has/get` 返回 miss
   2. 触发 data/meta 清理（best effort）
3. `clearUnusedSince`：
   1. 继续按 `lastAccessAtMs` 清理“长期未访问”
   2. 额外清理已过 `expireAtMs` 条目

## 6. 风险与规避

1. 风险：TTL 过短导致频繁重下。
   1. 建议默认不启用
   2. 在文档明确推荐值（如 1h/1d）
2. 风险：读路径续期导致额外写 IO。
   1. 默认关闭 `refreshExpireAtOnRead`
   2. 续期与 touch 共用节流窗口
3. 风险：调用方传负值 TTL。
   1. 入参归一化并记录日志

## 7. 测试计划

## 7.1 单元测试

1. `ttl=null` -> `expireAtMs=null`
2. `ttl=1s` -> 命中前有效、到期后 miss
3. `ttlOverride` 覆盖全局 TTL
4. 负值 TTL 归一化行为
5. 旧 meta（无 `expireAtMs`）兼容读取

## 7.2 集成测试

1. `XNZNetworkImageProvider` 写入带 TTL 的缓存
2. 到期后触发重新下载并重写 meta
3. `clearUnusedSince` 与 `expireAtMs` 并存时行为正确

## 8. 执行清单（可勾选）

## Phase A - API 骨架

- [ ] A1. `XNZCacheManager` 增加 `diskCacheDefaultTtl` 与 setter
- [ ] A2. `setCache` 增加 `ttlOverride` 参数（保持向后兼容）
- [ ] A3. Web stub 与接口签名同步

## Phase B - 磁盘写入联动

- [ ] B1. `XNZDiskCache.set` 支持 `expireAtMs` 入参
- [ ] B2. meta 写入 `expireAtMs`
- [ ] B3. 入参归一化（null/zero/negative）

## Phase C - 测试

- [ ] C1. TTL 基础单测（null/positive/expired）
- [ ] C2. override 优先级单测
- [ ] C3. 兼容性单测（旧 meta）
- [ ] C4. 回归测试确保现有默认行为不变

## Phase D - 文档

- [ ] D1. README 增加 TTL 配置说明（中/英）
- [ ] D2. 标注默认关闭与推荐场景
- [ ] D3. 标注 absolute 与 sliding（若后续启用）差异

## 9. 建议推进顺序

1. 先做 Phase A + B（功能可用且不破坏默认行为）。
2. 再补 Phase C（保证过期边界稳定）。
3. 最后做 Phase D（对外说明与示例）。
