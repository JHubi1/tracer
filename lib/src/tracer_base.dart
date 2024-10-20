import 'dart:core';
import 'package:intl/intl.dart';
import 'package:event/event.dart';
import 'package:stack_trace/stack_trace.dart';

String _helperTextCenter(String text) {
  var width = 5;
  if (text.length >= width) return text;

  int totalPadding = width - text.length;
  int padLeft = totalPadding ~/ 2;
  int padRight = totalPadding - padLeft;

  return (" " * padLeft) + text + (" " * padRight);
}

/// The different levels of logging severity.
enum TracerLevel {
  /// A level of information not important to the normal user. Hidden by default.
  debug("Debug", 90, 0),

  /// A level of information for certain, non-important events.
  info("Info", 94, 1),

  /// A level of information to warn the user about events that do not affect the
  /// experience in any severe way.
  warn("Warn", 93, 2),

  /// A level for issues occurring that may hinder certain features of the app,
  /// but don't affect the product as a whole. Limited usage should be possible.
  error("Error", 91, 3, useStderr: true),

  /// A level for severe issues occurring that drastically limit the app
  /// experience. The program should be exited.
  fatal("Fatal", 91, 4, useStderr: true);

  /// Name of the level. Used for data outputs.
  final String name;

  /// The color code used for generated outputs.
  final int ansiColor;

  /// The weight of the level. Used to determine if the level should be handled.
  final int importance;

  /// Whether the console output should use stderr for this level.
  final bool useStderr;

  const TracerLevel(this.name, this.ansiColor, this.importance,
      {this.useStderr = false});
}

/// The payload for a new log message event. Should not be created manually.
class TracerEventData extends EventArgs {
  /// The name of the section this event was created in.
  final String section;

  /// The level of severity.
  final TracerLevel level;

  /// The time of logging.
  final DateTime timestamp;

  /// A brief summary of what the issue is.
  final String body;

  /// A more detailed optional description of the issue.
  final String? description;

  /// The error object that was attached to the log event.
  ///
  /// Careful: this is not a standardized class!
  final Object? error;

  /// The stack object that was attached to the log event.
  final Trace? stack;

  /// Whether to use indentation in the output. This is only used in the
  /// [TracerEventData]s generated message. It can be useful if the console is
  /// quite narrow, so every bit of space is important.
  bool indentation;

  TracerEventData(this.section, this.level, this.timestamp, this.body,
      {required this.description,
      required this.error,
      required this.stack,
      this.indentation = true});

  /// Creates a rich output including a [timestamp], the severity [level], and
  /// the [body]. If given, it also embeds the [description], [error] and
  /// [stack]. Stacks are formatted into a human readable format.
  String get generatedMessageColored {
    var time = DateFormat("yyyy-MM-dd HH:mm:ss").format(timestamp);

    // hacky solution, related: https://github.com/dart-lang/i18n/issues/330
    time +=
        " ${"${timestamp.timeZoneOffset.inHours >= 0 ? '+' : '-'}${timestamp.timeZoneOffset.inHours.abs().toString().padLeft(2, '0')}${timestamp.timeZoneOffset.inMinutes.remainder(60).abs().toString().padLeft(2, '0')}"}";

    var text =
        "\x1B[0m[$time] \x1B[${level.ansiColor.toString()}m${_helperTextCenter(level.name)}: $section: $body\x1B[0m";

    var separator = "\n${" " * (time.length + 3)}|";
    if (!indentation) separator = "\n|";

    if (description != null && description!.isNotEmpty) {
      text += "$separator> ${description!.replaceAll("\n", "$separator  ")}";
    }
    if (error != null && error.toString().isNotEmpty) {
      text +=
          "$separator- \x1B[${level.ansiColor.toString()}m${error.toString().trim().replaceAll("\n", "\x1B[0m$separator  \x1B[${level.ansiColor.toString()}m")}\x1B[0m";
    }
    if (stack != null) {
      text += "$separator- \x1B[${level.ansiColor.toString()}m${stack!.foldFrames((p0) {
            return false;
          }, terse: true).toString().trim().replaceAll("\n", "\x1B[0m$separator  \x1B[${level.ansiColor.toString()}m")}\x1B[0m";
    }
    return text;
  }

  /// Creates an output including a [timestamp], the severity [level], and the
  /// [body]. If given, it also embeds the [description], [error] and [stack].
  /// Stacks are formatted into a human readable format.
  String get generatedMessage =>
      generatedMessageColored.replaceAll(RegExp(r'\x1B\[[0-9]+m'), "");
}

/// Blueprint for handlers.
///
/// A handler is called every time a new log message is received. In it, you can
/// do whatever you want with the data. Saving it to disk, outputting it, etc.
///
/// There are a few pre made handlers: [TracerConsoleHandler],
/// [TracerSimpleConsoleHandler], [TracerFileHandler]
///
/// To create a new handler, extend this class with the [handle] function. The
/// new class may also include a constructor.
///
/// ```dart
/// class TracerTestHandler extends TracerHandler {
///   @override
///   void handle(TracerEventData data) {
///     print(data.body);
///   }
/// }
/// ```
///
/// You can then use this handler by adding it to your [Tracer] object
/// constructor.
///
/// ```dart
/// var tracer = Tracer("example", handlers: [
///   TracerTestHandler()
/// ]);
/// ```
abstract class TracerHandler {
  TracerHandler();

  /// The function handling the event.
  void handle(TracerEventData data);
}

/// Blueprint for filters.
///
/// A handler is called every time right before a new log message is created. In
/// it, you can decide whether you want to filter that message.
///
/// Currently, there are no pre made filters.
///
/// To create a new handler, extend this class with the [handle] function. The
/// log event will be dismissed if the [handle] function returns `false`. The
/// new class may also include a constructor.
///
/// ```dart
/// class TracerTestFilter extends TracerFilter {
///   @override
///   bool handle(TracerEventData data) {
///     return data.body.contains("happy");
///   }
/// }
/// ```
///
/// You can then use this filter by adding it to your [Tracer] object
/// constructor.
///
/// ```dart
/// var tracer = Tracer("example", filters: [
///   TracerTestFilter()
/// ]);
/// ```
abstract class TracerFilter {
  TracerFilter();
  bool handle(TracerEventData data);
}

/// The main object for the Tracer library.
///
/// This includes all the logging functions and functionality you need to start
/// your logging adventure. Firstly you have to create your logging object:
///
/// ```dart
/// var tracer = Tracer("example");
/// ```
///
/// The [section] can be whatever you'd like it to be. It is used in
/// [TracerFileHandler.shareFile] if it's false, or in the [TracerConsoleHandler]
/// output. It's the only necessary part of the [Tracer] class.
///
/// _**Important:**_ Your [Tracer] object won't output anything without having
/// specified and value for handlers. You have to specify at least one to see
/// something:
///
/// ```dart
/// var tracer = Tracer("example", handlers: [
///   TracerConsoleHandler()
/// ]);
/// ```
///
/// Use the handlers and filters argument with [TracerHandler] and [TracerFilter]
/// to control the output of the logger.
///
/// You can select which errors are shown using the [logLevel] argument. The
/// set value is the smallest one allowed. Only events using it and any above
/// will get handled.
class Tracer {
  /// Unique identifier for this [Tracer] instance.
  final String section;

  /// The minimum level that has to be met. Lower levels will be ignored.
  TracerLevel logLevel;

  /// Whether to use indentation in the output.
  ///
  /// This is only used in the [TracerEventData]s generated message. It can be
  /// useful if the console is quite narrow, so every bit of space is important.
  bool indentation;

  /// A list of all [TracerEventData]s generated in this session.
  List<TracerEventData> get logs => _logs;
  final List<TracerEventData> _logs = [];

  /// The composed version os [logs], a string of all [TracerEventData]s
  /// generated in this session.
  String get logsGenerated => _logsGenerated;
  String _logsGenerated = "";

  final List<TracerFilter> _filters;

  Tracer(String section,
      {this.logLevel = TracerLevel.info,
      List<TracerHandler> handlers = const [],
      List<TracerFilter> filters = const [],
      this.indentation = true})
      : section = section.trim(),
        _filters = filters {
    assert(this.section.isNotEmpty);
    assert(RegExp(r'[a-zA-Z0-9_]+').hasMatch(this.section));

    listen((data) {
      _logs.add(data);
      _logsGenerated += "${data.generatedMessage}\n";
    });

    for (var handler in handlers) {
      listen(handler.handle);
    }
  }

  final _onLog = Event<TracerEventData>();

  /// Subscribe to the log event. This may no longer be used in favor of
  /// [TracerHandler].
  void listen(void Function(TracerEventData data) handler) {
    _onLog.subscribe(handler);
  }

  /// Unsubscribe from the log event. This may no longer be used in favor of
  /// [TracerHandler].
  ///
  /// [handler] has to be the exact same function that [listen] was used
  /// with, otherwise this function will return false.
  bool ignore(void Function(TracerEventData) handler) {
    return _onLog.unsubscribe(handler);
  }

  /// Create a raw log event.
  ///
  /// This may not be used, instead use one of the following sub functions:
  /// [debug], [info], [warn], [error], [fatal]
  void log(TracerLevel level, String body,
      {String? description,
      Object? errorObj,
      StackTrace? stack,
      bool? exitOnFatal}) {
    var event = TracerEventData(section, level, DateTime.now(), body.trim(),
        description: (description == null) ? null : description.trim(),
        error: errorObj,
        stack: (stack == null) ? null : Trace.from(stack),
        indentation: indentation);
    if (level.importance < logLevel.importance) return;
    for (var filter in _filters) {
      if (!filter.handle(event)) return;
    }
    _onLog.broadcast(event);
  }

  /// Creates a new log event with the [TracerLevel.debug].
  ///
  /// Use this to display information not important to the normal user.
  void debug(String body, {String? description}) {
    log(TracerLevel.debug, body, description: description);
  }

  /// Creates a new log event with the [TracerLevel.info].
  ///
  /// Use this to display information for certain, non-important events.
  void info(String body, {String? description}) {
    log(TracerLevel.info, body, description: description);
  }

  /// Creates a new log event with the [TracerLevel.warn].
  ///
  /// Use this to display information to warn the user about events that do not
  /// affect the experience in any severe way.
  void warn(String body,
      {String? description, Object? error, StackTrace? stack}) {
    log(TracerLevel.warn, body,
        description: description, errorObj: error, stack: stack);
  }

  /// Creates a new log event with the [TracerLevel.error].
  ///
  /// Use this to display issues occurring that may hinder certain features of
  /// the app, but don't affect the product as a whole.
  void error(String body,
      {String? description, Object? error, StackTrace? stack}) {
    log(TracerLevel.error, body,
        description: description, errorObj: error, stack: stack);
  }

  /// Creates a new log event with the [TracerLevel.fatal].
  ///
  /// Use this to display issues occurring that drastically limit the app
  /// experience. The program should be exited.
  void fatal(String body,
      {String? description, Object? error, StackTrace? stack}) {
    log(TracerLevel.fatal, body,
        description: description, errorObj: error, stack: stack);
  }
}
