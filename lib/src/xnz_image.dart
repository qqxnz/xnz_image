import 'package:xnz_image_core/xnz_image_core.dart';

class XNZImage {
  static void support(XNZImageSupport support) {
    XNZImageRegistry.instance.support(support);
  }

  static bool unsupport(String id) {
    return XNZImageRegistry.instance.unsupport(id);
  }

  static void clearSupports() {
    XNZImageRegistry.instance.clear();
  }

  static List<XNZImageSupport> get supports {
    return XNZImageRegistry.instance.supports;
  }
}
