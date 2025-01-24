import 'dart:async';
import 'dart:io';

import 'package:tracer/tracer.dart';

void main() {
  var t = Tracer("example", logLevel: TracerLevel.debug, handlers: [
    TracerConsoleHandler(),
    TracerFileHandler(File("logs/test.log")),
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
}
