import 'dart:collection';
import 'dart:typed_data';

class XNZMemoryCache<K> {
  final int maxBytes;
  int _currentBytes = 0;

  final LinkedHashMap<K, Uint8List> _cache = LinkedHashMap();

  XNZMemoryCache(this.maxBytes);

  bool has(K key) => _cache.containsKey(key);

  Uint8List? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      // LRU：移动到最后
      _cache[key] = value;
    }
    return value;
  }

  void put(K key, Uint8List value) {
    // 如果 key 已存在，先移除旧数据
    if (_cache.containsKey(key)) {
      _currentBytes -= _cache[key]!.lengthInBytes;
      _cache.remove(key);
    }

    _cache[key] = value;
    _currentBytes += value.lengthInBytes;

    // 超出内存上限，持续淘汰最旧的
    while (_currentBytes > maxBytes && _cache.isNotEmpty) {
      final oldestKey = _cache.keys.first;
      final removed = _cache.remove(oldestKey)!;
      _currentBytes -= removed.lengthInBytes;
    }
  }

  void remove(K key) {
    final removed = _cache.remove(key);
    if (removed != null) {
      _currentBytes -= removed.lengthInBytes;
    }
  }

  void clearAll() {
    _cache.clear();
    _currentBytes = 0;
  }

  int get currentBytes => _currentBytes;

  int get length => _cache.length;
}
