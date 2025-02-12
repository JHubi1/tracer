import 'dart:core';
import 'dart:async';

import 'package:intl/intl.dart';
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

/// The payload for a new log message event.
class TracerEventData {
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

  /// Whether to use indentation in the output.
  ///
  /// This is only used in the [TracerEventData]s generated message. It can be
  /// useful if the console is quite narrow, so every bit of space is important.
  bool indentation;

  TracerEventData._(
      {required this.section,
      required this.level,
      required this.timestamp,
      required this.body,
      required this.description,
      required this.error,
      required this.stack,
      required this.indentation});

  /// Creates a rich output.
  ///
  /// This included a [timestamp], the severity [level], and the [body].
  /// If given, it also embeds the [description], [error] and [stack].
  ///
  /// Stacks are formatted into a human readable format.
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

  /// Creates a plain-text output.
  ///
  /// This included a [timestamp], the severity [level], and the [body].
  /// If given, it also embeds the [description], [error] and [stack].
  ///
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
  /// The function handling the event.
  void handle(TracerEventData data);

  /// Called when the handler is no longer needed.
  void dispose() {}

  StreamSubscription? subscription;

  @override
  bool operator ==(Object other) {
    return other is TracerHandler && other.handle == handle;
  }

  @override
  int get hashCode => handle.hashCode;
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
  /// The function handling the event.
  bool handle(TracerEventData data);

  /// Called when the handler is no longer needed.
  void dispose() {}

  @override
  bool operator ==(Object other) {
    return other is TracerFilter && other.handle == handle;
  }

  @override
  int get hashCode => handle.hashCode;
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

  /// Whether to use UTC time for the timestamps.
  ///
  /// If this is set to true, the timestamps will be in UTC time. Otherwise, the
  /// local time will be used.
  ///
  /// This is useful if you want to have a consistent time format across all
  /// logs, regardless of the timezone of the system.
  ///
  /// To make behavior consistent, this may not be changed after the object is
  /// created.
  final bool forceUtc;

  /// A list of all [TracerEventData]s generated in this session.
  final List<TracerEventData> _logs = [];
  List<TracerEventData> get logs => _logs;

  /// The composed version os [logs], a string of all [TracerEventData]s
  /// generated in this session.
  String _logsGenerated = "";
  String get logsGenerated => _logsGenerated;

  /// A list of all handlers added to this [Tracer] object.
  final List<TracerHandler> _handlers;
  List<TracerHandler> get handlers => _handlers;

  /// A list of all filters added to this [Tracer] object.
  final List<TracerFilter> _filters;
  List<TracerFilter> get filters => _filters;

  final _stream = StreamController<TracerEventData>.broadcast(sync: true);

  Tracer(String section,
      {this.logLevel = TracerLevel.info,
      this.indentation = true,
      this.forceUtc = false,
      List<TracerHandler> handlers = const [],
      List<TracerFilter> filters = const []})
      : section = section.trim(),
        _handlers = [],
        _filters = filters {
    assert(this.section.isNotEmpty);
    assert(RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*').hasMatch(this.section));

    _stream.stream.listen((data) {
      _logs.add(data);
      _logsGenerated += "${data.generatedMessage}\n";
    });

    for (var i = 0; i < handlers.length; i++) {
      _add(handlers[i], argument: "handlers[$i]");
    }
  }

  /// Cancels a handler.
  ///
  /// This will cancel the subscription of the handler, effectively stopping it
  /// from receiving any more events. If the handler is not found, nothing will
  /// happen.
  ///
  /// Alternatively, you can use the [cancelAt] function to cancel a handler by
  /// index. This is useful if you want to cancel a handler order they were added.
  void cancel(TracerHandler handler) {
    for (var i = 0; i < _handlers.length; i++) {
      if (_handlers[i] == handler) {
        _handlers[i].dispose();
        _handlers[i].subscription?.cancel();
        _handlers.removeAt(i);
        return;
      }
    }
  }

  /// Cancels a handler by index.
  ///
  /// This will cancel the subscription of the handler, effectively stopping it
  /// from receiving any more events. If the index is out of bounds, nothing
  /// will happen.
  ///
  /// Alternatively, you can use the [cancel] function to cancel a handler by
  /// object. This is useful if you want to cancel a specific handler.
  void cancelAt(int index) {
    if (index < 0 || index >= _handlers.length) return;
    _handlers[index].dispose();
    _handlers[index].subscription?.cancel();
    _handlers.removeAt(index);
  }

  void _add(TracerHandler handler, {String argument = "handler"}) {
    if (_handlers.contains(handler)) return;
    if (handler.subscription != null) {
      throw ArgumentError("Handler already has a subscription.", argument);
    }
    handler.subscription = _stream.stream.listen(handler.handle);
    _handlers.add(handler);
  }

  /// Add a new handler to the [Tracer] object.
  ///
  /// Also see [TracerHandler] to learn more.
  void add(TracerHandler handler) => _add(handler);

  /// Cancels all handlers.
  ///
  /// This will cancel the subscription of all handlers, effectively stopping
  /// them from receiving any more events.
  ///
  /// If you want to cancel a specific handler, use the [cancel] function.
  /// If you want to cancel a handler by index, use the [cancelAt] function.
  void dispose() {
    for (var handler in _handlers) {
      handler.dispose();
      handler.subscription?.cancel();
    }
    _handlers.clear();
    _stream.close();
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
    final timestamp = DateTime.now();
    final event = TracerEventData._(
        section: section,
        level: level,
        timestamp: forceUtc ? timestamp.toUtc() : timestamp,
        body: body.trim(),
        description: (description == null) ? null : description.trim(),
        error: errorObj,
        stack: (stack == null) ? null : Trace.from(stack),
        indentation: indentation);
    if (level.importance < logLevel.importance) return;
    for (var filter in _filters) {
      if (!filter.handle(event)) return;
    }
    _stream.add(event);
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
