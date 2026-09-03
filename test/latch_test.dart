import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roac/latch.dart';

void main() {
  test('a latch drops the passes that overlap one already in flight', () async {
    const expected = 1;
    final latch = Latch('a task');
    final held = Completer<void>();
    var passes = 0;

    final first = latch.run(() async {
      passes++;
      await held.future;
    });
    await latch.run(() async => passes++);
    held.complete();
    await first;

    expect(passes, expected);
  });

  test('a latch reports a failed pass and stands open for the next', () async {
    const expected = (reports: 1, ranAfter: true);
    final latch = Latch('a task');
    final reports = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reports.add;
    addTearDown(() => FlutterError.onError = previous);
    var ranAfter = false;

    await latch.run(() async => throw StateError('the platform said no'));
    await latch.run(() async => ranAfter = true);

    final actual = (reports: reports.length, ranAfter: ranAfter);
    expect(actual, expected);
  });

  test(
    'a latch reports a lasting failure once, and anew once it has mended',
    () async {
      const expected = (whileFailing: 1, afterMending: 2);
      final latch = Latch('a task');
      final reports = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reports.add;
      addTearDown(() => FlutterError.onError = previous);

      await latch.run(() async => throw StateError('the platform said no'));
      await latch.run(() async => throw StateError('and said no again'));
      final whileFailing = reports.length;
      await latch.run(() async {});
      await latch.run(() async => throw StateError('and once more'));

      final actual = (whileFailing: whileFailing, afterMending: reports.length);
      expect(actual, expected);
    },
  );
}
