import 'package:xnz_image/xnz_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSupport implements XNZImageSupport {
  _FakeSupport({required this.idValue, required this.priorityValue});

  final String idValue;
  final int priorityValue;

  @override
  String get id => idValue;

  @override
  int get priority => priorityValue;

  @override
  bool canHandle(XNZImageRequest request) => true;

  @override
  XNZImageBuildResult resolve(XNZImageRequest request) {
    return XNZImageBuildResult.widget(
      widget: const SizedBox.shrink(),
      format: idValue,
    );
  }
}

void main() {
  setUp(() {
    XNZImage.clearSupports();
  });

  test('support uses id for override', () {
    XNZImage.support(_FakeSupport(idValue: 'dup', priorityValue: 1));
    XNZImage.support(_FakeSupport(idValue: 'dup', priorityValue: 9));

    expect(XNZImage.supports.length, 1);
    expect(XNZImage.supports.first.priority, 9);
  });

  test('supports are sorted by priority descending', () {
    XNZImage.support(_FakeSupport(idValue: 'low', priorityValue: 1));
    XNZImage.support(_FakeSupport(idValue: 'high', priorityValue: 100));

    final ids = XNZImage.supports.map((e) => e.id).toList();
    expect(ids, <String>['high', 'low']);
  });

  test('unsupport and clearSupports remove supports', () {
    XNZImage.support(_FakeSupport(idValue: 'a', priorityValue: 1));
    XNZImage.support(_FakeSupport(idValue: 'b', priorityValue: 2));

    expect(XNZImage.unsupport('a'), isTrue);
    expect(XNZImage.supports.map((e) => e.id), <String>['b']);

    XNZImage.clearSupports();
    expect(XNZImage.supports, isEmpty);
  });
}
