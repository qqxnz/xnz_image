import 'package:xnz_image_core/xnz_image_core.dart';

/// Global registry helpers for managing [XNZImageSupport] implementations.
class XNZImage {
  /// Registers a support implementation into the global image registry.
  static void support(XNZImageSupport support) {
    XNZImageLogs.log('XNZImage', 'support ${support.id}');
    XNZImageRegistry.instance.support(support);
  }

  /// Unregisters a support implementation by [id].
  ///
  /// Returns `true` when an existing support was removed.
  static bool unsupport(String id) {
    final removed = XNZImageRegistry.instance.unsupport(id);
    XNZImageLogs.log('XNZImage', 'unsupport $id removed:$removed');
    return removed;
  }

  /// Clears all registered support implementations.
  static void clearSupports() {
    XNZImageLogs.log('XNZImage', 'clearSupports');
    XNZImageRegistry.instance.clear();
  }

  /// Returns current registered support implementations.
  static List<XNZImageSupport> get supports {
    return XNZImageRegistry.instance.supports;
  }
}
