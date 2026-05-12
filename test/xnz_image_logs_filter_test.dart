import 'package:flutter_test/flutter_test.dart';
import 'package:xnz_image/xnz_image.dart';

void main() {
  test('XNZImageLogs emits all logs when filter is all', () {
    final logs = <String>[];
    XNZImageLogs.showLogs = false;
    XNZImageLogs.logFilter = XNZImageLogFilter.all;
    XNZImageLogs.setInterceptor((tag, log) {
      logs.add('$tag|$log');
      return true;
    });

    XNZImageLogs.event('XNZTest', 'task_complete');
    XNZImageLogs.event('XNZTest', 'task_failed');
    XNZImageLogs.event('XNZTest', 'obtain_key');

    expect(logs.length, 3);

    XNZImageLogs.setInterceptor(null);
    XNZImageLogs.logFilter = XNZImageLogFilter.all;
  });

  test('XNZImageLogs emits only success logs when filter is success', () {
    final logs = <String>[];
    XNZImageLogs.showLogs = false;
    XNZImageLogs.logFilter = XNZImageLogFilter.success;
    XNZImageLogs.setInterceptor((tag, log) {
      logs.add('$tag|$log');
      return true;
    });

    XNZImageLogs.event('XNZTest', 'task_complete');
    XNZImageLogs.event('XNZTest', 'task_failed');
    XNZImageLogs.event('XNZTest', 'obtain_key');

    expect(logs.length, 1);
    expect(logs.first, contains('[XNZTest][task_complete]'));

    XNZImageLogs.setInterceptor(null);
    XNZImageLogs.logFilter = XNZImageLogFilter.all;
  });

  test('XNZImageLogs emits only failure logs when filter is failure', () {
    final logs = <String>[];
    XNZImageLogs.showLogs = false;
    XNZImageLogs.logFilter = XNZImageLogFilter.failure;
    XNZImageLogs.setInterceptor((tag, log) {
      logs.add('$tag|$log');
      return true;
    });

    XNZImageLogs.event('XNZTest', 'task_complete');
    XNZImageLogs.event('XNZTest', 'task_failed');
    XNZImageLogs.event('XNZTest', 'obtain_key');

    expect(logs.length, 1);
    expect(logs.first, contains('[XNZTest][task_failed]'));

    XNZImageLogs.setInterceptor(null);
    XNZImageLogs.logFilter = XNZImageLogFilter.all;
  });
}
