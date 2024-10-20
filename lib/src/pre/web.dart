import 'dart:js_interop';
import 'package:web/web.dart';
import 'package:tracer/src/tracer_base.dart';

/// A handler outputting the log events to the JavaScript console.
///
/// It uses [TracerEventData.generatedMessage].
class TracerConsoleHandler extends TracerHandler {
  @override
  void handle(TracerEventData data) {
    var text = data.generatedMessage;
    if (data.level == TracerLevel.debug) {
      console.debug(text.toJS);
    } else if (data.level == TracerLevel.info) {
      console.info(text.toJS);
    } else if (data.level == TracerLevel.warn) {
      console.warn(text.toJS);
    } else if (data.level == TracerLevel.error) {
      console.error(text.toJS);
    } else if (data.level == TracerLevel.fatal) {
      console.error(text.toJS);
    } else {
      if (data.level.useStderr) {
        console.error(text.toJS);
      } else {
        console.log(text.toJS);
      }
    }
  }
}

/// A simplified handler outputting the log events to the JavaScript console.
///
/// It outputs very simple versions of the output and **SHOULD NOT** be used
/// in production applications, for that use [TracerConsoleHandler].
///
/// This is more used as an example.
class TracerSimpleConsoleHandler extends TracerHandler {
  @override
  void handle(TracerEventData data) {
    console
        .log("${data.level.name.toLowerCase().padRight(5)}> ${data.body}".toJS);
  }
}
