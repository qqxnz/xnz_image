import 'package:flutter/widgets.dart';
import 'package:xnz_net_cache_image/src/xnz_cache_manager.dart';
import 'package:xnz_net_cache_image/src/xnz_image_cache_logs.dart';

class XNZCacheMemoryObserver with WidgetsBindingObserver {
  static final XNZCacheMemoryObserver _instance =
  XNZCacheMemoryObserver._internal();

  XNZCacheMemoryObserver._internal();

  factory XNZCacheMemoryObserver() => _instance;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    XNZNetworkImageLogs.log('XNZNetworkImage', 'MemoryObserver init');
  }

  @override
  void didHaveMemoryPressure() {
    XNZNetworkImageLogs.log(
      'XNZNetworkImage',
      '⚠️ Memory pressure detected → clear memory cache',
    );

    XNZCacheManager().memoryCache.clearAll();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
