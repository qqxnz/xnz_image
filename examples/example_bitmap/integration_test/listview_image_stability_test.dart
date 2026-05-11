import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xnz_image/xnz_image.dart';
import 'package:xnz_image_example_bitmap/main.dart';

import 'test_data/bulk_image_urls.dart';

const _invalidDemoImageUrl = 'https://sssa';

void _printReport(String title, Map<String, dynamic> payload) {
  print('===== $title =====');
  print(const JsonEncoder.withIndent('  ').convert(payload));
}

Future<void> _pumpFor(
  WidgetTester tester,
  Duration duration, {
  Duration step = const Duration(milliseconds: 16),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

class _BulkImageListApp extends StatelessWidget {
  const _BulkImageListApp({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Bulk Network Image List')),
        body: ListView.builder(
          key: const ValueKey('bulk_image_list'),
          itemCount: urls.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('[$index] ${urls[index]}', maxLines: 1),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    child: XNZNetworkImage(
                      imageUrl: urls[index],
                      fit: BoxFit.cover,
                      loadFailedBuilder: (url, error) =>
                          Text('load failed: $index'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
      as IntegrationTestWidgetsFlutterBinding;

  testWidgets(
    'ListView image loading + scroll stress + frame timing monitoring',
    (tester) async {
      final imageLogs = <String>[];
      final imageFailures = <String>[];
      final flutterErrors = <FlutterErrorDetails>[];
      final uncaughtErrors = <Object>[];
      final frameTimings = <FrameTiming>[];

      final previousShowLogs = XNZImageLogs.showLogs;
      final previousOnError = FlutterError.onError;
      final previousPlatformError = PlatformDispatcher.instance.onError;

      void onFrameTimings(List<FrameTiming> timings) {
        frameTimings.addAll(timings);
      }

      XNZImageLogs.showLogs = false;
      XNZImageLogs.setInterceptor((tag, log) {
        final message = '$tag|$log';
        imageLogs.add(message);
        if (log.contains('失败') ||
            log.contains('error') ||
            log.contains('Error')) {
          imageFailures.add(message);
        }
        return true;
      });

      FlutterError.onError = (details) {
        flutterErrors.add(details);
        previousOnError?.call(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        uncaughtErrors.add(error);
        return false;
      };
      SchedulerBinding.instance.addTimingsCallback(onFrameTimings);

      try {
        await runZonedGuarded(() async {
          await tester.pumpWidget(const DemoApp());
          await _pumpFor(tester, const Duration(seconds: 3));
        }, (error, stack) {
          uncaughtErrors.add(error);
        });

        final listView = find.byType(ListView);
        final scrollable = find.byType(Scrollable);
        expect(listView, findsOneWidget);
        expect(scrollable, findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('XNZNetworkImage (Bitmap)'),
          240,
          scrollable: scrollable,
        );
        await _pumpFor(tester, const Duration(milliseconds: 400));

        await tester.scrollUntilVisible(
          find.text('XNZAssetImage (Bitmap)'),
          240,
          scrollable: scrollable,
        );
        await _pumpFor(tester, const Duration(milliseconds: 400));

        await tester.scrollUntilVisible(
          find.text('XNZAnimatedImage (GIF Asset)'),
          300,
          scrollable: scrollable,
        );
        await _pumpFor(tester, const Duration(milliseconds: 600));

        await tester.scrollUntilVisible(
          find.text('XNZAnimatedImage (GIF Network)'),
          300,
          scrollable: scrollable,
        );
        await _pumpFor(tester, const Duration(milliseconds: 600));

        await tester.scrollUntilVisible(
          find.text('XNZAnimatedImage (Static PNG)'),
          300,
          scrollable: scrollable,
        );
        await _pumpFor(tester, const Duration(milliseconds: 600));

        for (var i = 0; i < 8; i++) {
          await tester.drag(listView, const Offset(0, -500));
          await _pumpFor(tester, const Duration(milliseconds: 350));
        }
        for (var i = 0; i < 8; i++) {
          await tester.drag(listView, const Offset(0, 500));
          await _pumpFor(tester, const Duration(milliseconds: 350));
        }

        await _pumpFor(tester, const Duration(seconds: 2));

        await tester.scrollUntilVisible(
          find.text('Error Callback Demo'),
          240,
          scrollable: scrollable,
        );
        await _pumpFor(tester, const Duration(milliseconds: 300));

        expect(find.text('error callback triggered'), findsOneWidget);
        expect(
          imageFailures
              .any((message) => message.contains(_invalidDemoImageUrl)),
          isTrue,
          reason: 'Invalid URL should produce an image failure log.',
        );
        expect(
          flutterErrors,
          isEmpty,
          reason: 'Flutter framework errors occurred during scrolling.',
        );
        expect(
          uncaughtErrors,
          isEmpty,
          reason: 'Uncaught async errors occurred during integration run.',
        );

        final measured = frameTimings
            .where((timing) => timing.totalSpan > Duration.zero)
            .toList();
        expect(
          measured.length,
          greaterThan(20),
          reason: 'Frame timings were not captured as expected.',
        );

        var worstFrameMs = 0.0;
        var totalFrameMs = 0.0;
        var jankOver33Ms = 0;
        var severeJankOver100Ms = 0;

        for (final timing in measured) {
          final ms = timing.totalSpan.inMicroseconds / 1000.0;
          totalFrameMs += ms;
          worstFrameMs = math.max(worstFrameMs, ms);
          if (ms > 33.0) jankOver33Ms++;
          if (ms > 100.0) severeJankOver100Ms++;
        }

        final avgFrameMs = totalFrameMs / measured.length;
        final jankRate = jankOver33Ms / measured.length;
        final severeJankRate = severeJankOver100Ms / measured.length;

        expect(
          severeJankRate,
          lessThan(0.35),
          reason:
              'Too many severe jank frames (>100ms). rate=$severeJankRate, worst=${worstFrameMs.toStringAsFixed(2)}ms',
        );
        expect(
          worstFrameMs,
          lessThan(700.0),
          reason:
              'Single frame is too slow (possible freeze). worst=${worstFrameMs.toStringAsFixed(2)}ms',
        );

        final report = binding.reportData ?? <String, dynamic>{};
        report['frames_collected'] = measured.length;
        report['avg_frame_ms'] = avgFrameMs.toStringAsFixed(2);
        report['worst_frame_ms'] = worstFrameMs.toStringAsFixed(2);
        report['jank_rate_over_33ms'] = jankRate.toStringAsFixed(4);
        report['severe_jank_rate_over_100ms'] =
            severeJankRate.toStringAsFixed(4);
        report['image_log_count'] = imageLogs.length;
        report['image_failure_log_count'] = imageFailures.length;
        binding.reportData = report;
        _printReport('Base ListView Report', <String, dynamic>{
          'frames_collected': report['frames_collected'],
          'avg_frame_ms': report['avg_frame_ms'],
          'worst_frame_ms': report['worst_frame_ms'],
          'jank_rate_over_33ms': report['jank_rate_over_33ms'],
          'severe_jank_rate_over_100ms': report['severe_jank_rate_over_100ms'],
          'image_log_count': report['image_log_count'],
          'image_failure_log_count': report['image_failure_log_count'],
        });
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(onFrameTimings);
        XNZImageLogs.showLogs = previousShowLogs;
        XNZImageLogs.setInterceptor(null);
        FlutterError.onError = previousOnError;
        PlatformDispatcher.instance.onError = previousPlatformError;
      }
    },
  );

  testWidgets(
    'Bulk URL ListView scroll stress with provided image set',
    (tester) async {
      final imageLogs = <String>[];
      final flutterErrors = <FlutterErrorDetails>[];
      final uncaughtErrors = <Object>[];
      final frameTimings = <FrameTiming>[];

      final previousShowLogs = XNZImageLogs.showLogs;
      final previousOnError = FlutterError.onError;
      final previousPlatformError = PlatformDispatcher.instance.onError;

      void onFrameTimings(List<FrameTiming> timings) {
        frameTimings.addAll(timings);
      }

      XNZImageLogs.showLogs = false;
      XNZImageLogs.setInterceptor((tag, log) {
        imageLogs.add('$tag|$log');
        return true;
      });

      FlutterError.onError = (details) {
        flutterErrors.add(details);
        previousOnError?.call(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        uncaughtErrors.add(error);
        return false;
      };
      SchedulerBinding.instance.addTimingsCallback(onFrameTimings);

      try {
        await runZonedGuarded(() async {
          await tester.pumpWidget(_BulkImageListApp(urls: kBulkImageUrls));
          await _pumpFor(tester, const Duration(seconds: 4));
        }, (error, stack) {
          uncaughtErrors.add(error);
        });

        final listView = find.byKey(const ValueKey('bulk_image_list'));
        expect(listView, findsOneWidget);
        expect(kBulkImageUrls.length, greaterThanOrEqualTo(200));

        for (var i = 0; i < 22; i++) {
          await tester.drag(listView, const Offset(0, -700));
          await _pumpFor(tester, const Duration(milliseconds: 300));
        }
        for (var i = 0; i < 22; i++) {
          await tester.drag(listView, const Offset(0, 700));
          await _pumpFor(tester, const Duration(milliseconds: 300));
        }
        await _pumpFor(tester, const Duration(seconds: 3));

        final measured = frameTimings
            .where((timing) => timing.totalSpan > Duration.zero)
            .toList();
        expect(measured.length, greaterThan(80));
        expect(flutterErrors, isEmpty);
        expect(uncaughtErrors, isEmpty);
        expect(imageLogs.isNotEmpty, isTrue);

        var worstFrameMs = 0.0;
        var totalFrameMs = 0.0;
        var jankOver33Ms = 0;
        var severeJankOver100Ms = 0;

        for (final timing in measured) {
          final ms = timing.totalSpan.inMicroseconds / 1000.0;
          totalFrameMs += ms;
          worstFrameMs = math.max(worstFrameMs, ms);
          if (ms > 33.0) jankOver33Ms++;
          if (ms > 100.0) severeJankOver100Ms++;
        }

        final avgFrameMs = totalFrameMs / measured.length;
        final jankRate = jankOver33Ms / measured.length;
        final severeJankRate = severeJankOver100Ms / measured.length;

        expect(
          severeJankRate,
          lessThan(0.55),
          reason:
              'Bulk image list severe jank is too high. rate=$severeJankRate',
        );
        expect(
          worstFrameMs,
          lessThan(1200.0),
          reason:
              'Bulk image list has a potential freeze. worst=$worstFrameMs ms',
        );

        final report = binding.reportData ?? <String, dynamic>{};
        report['bulk_url_count'] = kBulkImageUrls.length;
        report['bulk_frames_collected'] = measured.length;
        report['bulk_avg_frame_ms'] = avgFrameMs.toStringAsFixed(2);
        report['bulk_worst_frame_ms'] = worstFrameMs.toStringAsFixed(2);
        report['bulk_jank_rate_over_33ms'] = jankRate.toStringAsFixed(4);
        report['bulk_severe_jank_rate_over_100ms'] =
            severeJankRate.toStringAsFixed(4);
        report['bulk_image_log_count'] = imageLogs.length;
        binding.reportData = report;
        _printReport('Bulk ListView Report', <String, dynamic>{
          'bulk_url_count': report['bulk_url_count'],
          'bulk_frames_collected': report['bulk_frames_collected'],
          'bulk_avg_frame_ms': report['bulk_avg_frame_ms'],
          'bulk_worst_frame_ms': report['bulk_worst_frame_ms'],
          'bulk_jank_rate_over_33ms': report['bulk_jank_rate_over_33ms'],
          'bulk_severe_jank_rate_over_100ms':
              report['bulk_severe_jank_rate_over_100ms'],
          'bulk_image_log_count': report['bulk_image_log_count'],
        });
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(onFrameTimings);
        XNZImageLogs.showLogs = previousShowLogs;
        XNZImageLogs.setInterceptor(null);
        FlutterError.onError = previousOnError;
        PlatformDispatcher.instance.onError = previousPlatformError;
      }
    },
  );
}
