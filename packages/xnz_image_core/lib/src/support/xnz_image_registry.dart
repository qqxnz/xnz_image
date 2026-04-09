import 'xnz_image_support.dart';

class XNZImageRegistry {
  XNZImageRegistry._();

  static final XNZImageRegistry instance = XNZImageRegistry._();

  final Map<String, XNZImageSupport> _supports = <String, XNZImageSupport>{};
  List<XNZImageSupport> _sortedSupportsCache = const <XNZImageSupport>[];
  bool _supportsDirty = true;

  void support(XNZImageSupport support) {
    _supports[support.id] = support;
    _supportsDirty = true;
  }

  bool unsupport(String id) {
    final removed = _supports.remove(id) != null;
    if (removed) {
      _supportsDirty = true;
    }
    return removed;
  }

  void clear() {
    if (_supports.isNotEmpty) {
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
        return result;
      }
    }
    return null;
  }
}
