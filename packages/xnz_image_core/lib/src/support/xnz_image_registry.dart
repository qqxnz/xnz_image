import 'xnz_image_support.dart';

class XNZImageRegistry {
  XNZImageRegistry._();

  static final XNZImageRegistry instance = XNZImageRegistry._();

  final Map<String, XNZImageSupport> _supports = <String, XNZImageSupport>{};

  void support(XNZImageSupport support) {
    _supports[support.id] = support;
  }

  bool unsupport(String id) {
    return _supports.remove(id) != null;
  }

  void clear() {
    _supports.clear();
  }

  List<XNZImageSupport> get supports {
    final values = _supports.values.toList(growable: false);
    values.sort((a, b) => b.priority.compareTo(a.priority));
    return values;
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
