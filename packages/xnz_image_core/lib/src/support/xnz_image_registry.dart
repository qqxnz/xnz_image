import 'xnz_image_support.dart';
import '../xnz_image_cache_logs.dart';

class XNZImageRegistry {
  XNZImageRegistry._();

  static final XNZImageRegistry instance = XNZImageRegistry._();

  final Map<String, XNZImageSupport> _supports = <String, XNZImageSupport>{};
  List<XNZImageSupport> _sortedSupportsCache = const <XNZImageSupport>[];
  bool _supportsDirty = true;

  void support(XNZImageSupport support) {
    XNZImageLogs.log('XNZImageRegistry', 'support ${support.id}');
    _supports[support.id] = support;
    _supportsDirty = true;
  }

  bool unsupport(String id) {
    final removed = _supports.remove(id) != null;
    if (removed) {
      _supportsDirty = true;
    }
    XNZImageLogs.log('XNZImageRegistry', 'unsupport $id removed:$removed');
    return removed;
  }

  void clear() {
    if (_supports.isNotEmpty) {
      XNZImageLogs.log(
          'XNZImageRegistry', 'clear ${_supports.length} supports');
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
        XNZImageLogs.log(
          'XNZImageRegistry',
          'resolve ${request.sourceType.name} -> ${support.id}',
        );
        return result;
      }
    }
    XNZImageLogs.log(
        'XNZImageRegistry', 'resolve ${request.sourceType.name} -> miss');
    return null;
  }
}
