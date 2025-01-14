import 'dart:async';

import 'package:tracer/tracer.dart';
import 'package:test/test.dart';

var ranDebug = false;

class TracerTestDebug extends TracerHandler {
  @override
  void handle(TracerEventData data) {
    TracerConsoleHandler().handle(data);
    ranDebug = true;
  }
}

var ranInfo = false;

class TracerTestInfo extends TracerHandler {
  @override
  void handle(TracerEventData data) {
    TracerConsoleHandler().handle(data);
    ranInfo = true;
  }
}

var ranWarn = false;

class TracerTestWarn extends TracerHandler {
  @override
  void handle(TracerEventData data) {
    TracerConsoleHandler().handle(data);
    ranWarn = true;
  }
}

var ranError = false;

class TracerTestError extends TracerHandler {
  @override
  void handle(TracerEventData data) {
    TracerConsoleHandler().handle(data);
    ranError = true;
  }
}

var ranFatal = false;

class TracerTestFatal extends TracerHandler {
  @override
  void handle(TracerEventData data) {
    TracerConsoleHandler().handle(data);
    ranFatal = true;
  }
}

void main() {
  test("Debug", () async {
    expect(ranDebug, isFalse);
    final t = Tracer("testing_debug",
        logLevel: TracerLevel.debug, handlers: [TracerTestDebug()]);
    t.debug("This is a test debug message");
    await Future.delayed(Duration(milliseconds: 100));
    expect(ranDebug, isTrue);
  });
  test("Info", () async {
    expect(ranInfo, isFalse);
    final t = Tracer("testing_info", handlers: [TracerTestInfo()]);
    t.info("This is a test info message");
    await Future.delayed(Duration(milliseconds: 1));
    expect(ranInfo, isTrue);
  });
  test("Warn", () async {
    expect(ranWarn, isFalse);
    final t = Tracer("testing_warn", handlers: [TracerTestWarn()]);
    t.warn("This is a test warn message");
    await Future.delayed(Duration(milliseconds: 1));
    expect(ranWarn, isTrue);
  });
  test("Error", () async {
    expect(ranError, isFalse);
    final t = Tracer("testing_error", handlers: [TracerTestError()]);
    t.error("This is a test error message");
    await Future.delayed(Duration(milliseconds: 1));
    expect(ranError, isTrue);
  });
  test("Fatal", () async {
    expect(ranFatal, isFalse);
    final t = Tracer("testing_fatal", handlers: [TracerTestFatal()]);
    t.fatal("This is a test fatal message");
    await Future.delayed(Duration(milliseconds: 1));
    expect(ranFatal, isTrue);
  });
}
