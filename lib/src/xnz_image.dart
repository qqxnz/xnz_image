import 'package:xnz_image_core/xnz_image_core.dart';


class XNZImage {
  static void support(XNZImageSupport support) {
    XNZImageLogs.log('XNZImage', 'support ${support.id}');
    XNZImageRegistry.instance.support(support);
  }

  static bool unsupport(String id) {
    final removed = XNZImageRegistry.instance.unsupport(id);
    XNZImageLogs.log('XNZImage', 'unsupport $id removed:$removed');
    return removed;
  }

  static void clearSupports() {
    XNZImageLogs.log('XNZImage', 'clearSupports');
    XNZImageRegistry.instance.clear();
  }

  static List<XNZImageSupport> get supports {
    return XNZImageRegistry.instance.supports;
  }
}
