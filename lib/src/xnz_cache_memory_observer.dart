import 'package:flutter/widgets.dart';
import 'package:xnz_net_cache_image/src/xnz_cache.dart';
import 'package:xnz_net_cache_image/src/xnz_image_cache_logs.dart';

class XNZCacheMemoryObserver with WidgetsBindingObserver {
  static final XNZCacheMemoryObserver _instance =
  XNZCacheMemoryObserver._internal();

  XNZCacheMemoryObserver._internal();

  factory XNZCacheMemoryObserver() => _instance;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    XNZCacheImageLogs.log('XNZCacheImage', 'MemoryObserver init');
  }

  @override
  void didHaveMemoryPressure() {
    XNZCacheImageLogs.log(
      'XNZCacheImage',
      '⚠️ Memory pressure detected → clear memory cache',
    );

    XNZCache().memoryCache.clearAll();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
