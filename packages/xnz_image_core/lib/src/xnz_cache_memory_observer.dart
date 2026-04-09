import 'package:flutter/widgets.dart';
import 'package:xnz_image_core/src/xnz_cache_manager.dart';
import 'package:xnz_image_core/src/xnz_image_cache_logs.dart';

class XNZCacheMemoryObserver with WidgetsBindingObserver {
  static final XNZCacheMemoryObserver _instance =
      XNZCacheMemoryObserver._internal();

  XNZCacheMemoryObserver._internal();

  factory XNZCacheMemoryObserver() => _instance;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    XNZImageLogs.log('XNZNetworkImage', 'MemoryObserver init');
  }

  @override
  void didHaveMemoryPressure() {
    XNZImageLogs.log(
      'XNZNetworkImage',
      '⚠️ Memory pressure detected → clear memory cache',
    );

    XNZCacheManager().memoryCache.clearAll();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
