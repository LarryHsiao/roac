import 'package:flutter/foundation.dart';

/// A latch over one task that must not overlap itself.
///
/// While a pass is in flight the next is let go rather than queued — a timer
/// firing faster than the platform can answer would otherwise pile up work
/// nobody wants. A failed pass is reported rather than thrown, and always
/// leaves the latch open behind it.
///
/// A lasting failure is reported once, not on every pass: a task driven by a
/// 30Hz timer would otherwise bury the very report that matters under
/// thousands of its own copies. The report is armed afresh once a pass gets
/// through, so a failure that returns is heard again.
class Latch {
  Latch(this.task);

  /// What the latch guards, named for the error report.
  final String task;

  bool _held = false;
  bool _failing = false;

  Future<void> run(Future<void> Function() pass) async {
    if (_held) return;
    _held = true;
    try {
      await pass();
      _failing = false;
    } catch (error, stack) {
      if (_failing) return;
      _failing = true;
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'roac',
        context: ErrorDescription(task),
      ));
    } finally {
      _held = false;
    }
  }
}
