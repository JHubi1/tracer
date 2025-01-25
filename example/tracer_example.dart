import 'dart:io';
import 'dart:async';

import 'package:tracer/tracer.dart';

void main() {
  var t =
      Tracer("example", logLevel: TracerLevel.debug, forceUtc: true, handlers: [
    TracerConsoleHandler(),
    TracerFileHandler(File("logs/test.log"), append: false),
  ]);
  t.debug("This is a debug message");
  t.info("This is an info message");
  t.warn("This is a warning message");
  t.error("This is an error message");
  t.fatal("This is a fatal message");

  print("-----");

  t.info("This will have a description", description: "I AM THE DESCRIPTION!");
  t.warn("Multiline description", description: "Line 1\nLine 2\nLine 3");

  print("-----");

  try {
    throw Exception("This is an exception");
  } catch (e) {
    t.error("This is an error with an exception", error: e);
  }
  try {
    throw Exception("This is a second exception");
  } catch (e, s) {
    t.fatal("This is an error with an exception and stack trace",
        error: e, stack: s);
  }

  runZonedGuarded(() {
    throw Exception("This is an exception in a zone");
  }, (error, stack) {
    t.fatal(
        "This is an error with an exception and stack trace, triggered by a zone",
        error: error,
        stack: stack);
  });

  print("-----");

  t.info("The next message will be shown in 5 seconds");
  Future.delayed(Duration(seconds: 5), () {
    t.info("This message was delayed by 5 seconds");
  });
}
