import 'xnz_image_support.dart';
import '../xnz_image_cache_logs.dart';

class XNZImageRegistry {
  XNZImageRegistry._();

  static final XNZImageRegistry instance = XNZImageRegistry._();

  final Map<String, XNZImageSupport> _supports = <String, XNZImageSupport>{};
  List<XNZImageSupport> _sortedSupportsCache = const <XNZImageSupport>[];
  bool _supportsDirty = true;

  void support(XNZImageSupport support) {
    XNZImageLogs.event('XNZImageRegistry', 'support_register', fields: {
      'supportId': support.id,
    });
    _supports[support.id] = support;
    _supportsDirty = true;
  }

  bool unsupport(String id) {
    final removed = _supports.remove(id) != null;
    if (removed) {
      _supportsDirty = true;
    }
    XNZImageLogs.event('XNZImageRegistry', 'support_unregister', fields: {
      'supportId': id,
      'removed': removed,
    });
    return removed;
  }

  void clear() {
    if (_supports.isNotEmpty) {
      XNZImageLogs.event('XNZImageRegistry', 'support_clear_all', fields: {
        'count': _supports.length,
      });
      _supports.clear();
      _supportsDirty = true;
    }
  }

  List<XNZImageSupport> get supports {
    if (_supportsDirty) {
      final values = _supports.values.toList(growable: false);
      values.sort((a, b) => b.priority.compareTo(a.priority));
      _sortedSupportsCache = List<XNZImageSupport>.unmodifiable(values);
      _supportsDirty = false;
    }
    return _sortedSupportsCache;
  }

  XNZImageBuildResult? resolve(XNZImageRequest request) {
    for (final support in supports) {
      if (!support.canHandle(request)) {
        continue;
      }
      final result = support.resolve(request);
      if (result != null) {
        XNZImageLogs.event('XNZImageRegistry', 'resolve_hit', fields: {
          'sourceType': request.sourceType.name,
          'supportId': support.id,
        });
        return result;
      }
    }
    XNZImageLogs.event('XNZImageRegistry', 'resolve_miss', fields: {
      'sourceType': request.sourceType.name,
    });
    return null;
  }
}
