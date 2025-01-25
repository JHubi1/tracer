import 'dart:io';
import 'package:tracer/src/tracer_base.dart';
import 'package:intl/intl.dart';

/// A handler outputting the log events to the system console.
///
/// It uses [TracerEventData.generatedMessageColored] or
/// [TracerEventData.generatedMessage] depending on the attribute [useColors].
class TracerConsoleHandler extends TracerHandler {
  /// Whether to use colors for the console outputting.
  final bool useColors;

  /// Whether to use stderr and stdout for the outputting. Otherwise the default
  /// `print` function is used. This is useful if the platform doesn't support
  /// the direct stdout, like an Android app.
  final bool useStderr;

  TracerConsoleHandler({this.useColors = true, this.useStderr = false});

  @override
  void handle(TracerEventData data) {
    var text = useColors ? data.generatedMessageColored : data.generatedMessage;
    if (useStderr) {
      if (data.level.useStderr) {
        stderr.writeln(text);
      } else {
        stdout.writeln(text);
      }
    } else {
      print(text);
    }
  }
}

/// A simplified handler outputting the log events to the system console.
///
/// It outputs very simple versions of the output and **SHOULD NOT** be used
/// in production applications, for that use [TracerConsoleHandler].
///
/// This is more used as an example.
class TracerSimpleConsoleHandler extends TracerHandler {
  @override
  void handle(TracerEventData data) {
    print("${data.level.name.toLowerCase().padRight(5)}> ${data.body}");
  }
}

/// A handler outputting the log events to the file system.
///
/// It uses [TracerEventData.generatedMessage].
///
/// The log files are created in [dir]. If [useDate] is true `yyyy-MM-dd.log`
/// created in the directory, otherwise `latest.log` is used.
///
/// If [shareFile] is enabled, all sections (that have [dir] set to the same
/// directory) share the same log file. Otherwise a suffix with the section
/// name is added to the file name.
///
/// If you want to target a specific file, use [TracerFileHandler].
class TracerDirectoryHandler extends TracerHandler {
  /// The directory to create the log files in.
  final Directory dir;

  /// Whether to enable appending to the existing file.
  ///
  /// If disabled, the existing content of the log file will be wiped once the
  /// first log from this [Tracer] instance is created.
  final bool append;

  /// Whether not to add a suffix to the log file name.
  final bool shareFile;

  /// Whether to se the current date for the log file. If disabled `latest.log`
  /// is used.
  final bool useDate;

  bool _handledOverwrite = false;

  String _getFileName(TracerEventData data) {
    var name = "latest.log";
    if (useDate) {
      name = "${DateFormat("yyyy-MM-dd").format(data.timestamp)}.log";
    }
    if (!shareFile) name = "${data.section}.$name";
    return name;
  }

  TracerDirectoryHandler(this.dir,
      {this.append = true, this.shareFile = true, this.useDate = true}) {
    assert(!shareFile || append);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  @override
  void handle(TracerEventData data) {
    var file = File(dir.path + Platform.pathSeparator + _getFileName(data));

    if (!_handledOverwrite && !append && file.existsSync()) {
      file.writeAsStringSync("");
    }
    _handledOverwrite = true;

    file.writeAsStringSync("${data.generatedMessage}\n", mode: FileMode.append);
  }
}

/// An exception thrown by [TracerFileHandler].
///
/// This is thrown when the file handling fails. For example, when the file is
/// locked by another process or the file is not accessible.
class TracerFileHandlerException implements Exception {
  final dynamic message;

  TracerFileHandlerException([this.message]);

  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return "TracerFileHandlerException";
    return "TracerFileHandlerException: $message";
  }
}

/// A handler outputting the log events to a single file.
///
/// It uses [TracerEventData.generatedMessage].
///
/// Pass the file you want to write to to the constructor. This will lock the
/// file for the OS and future logs will be appended to it.
///
/// If [append] is disabled, the existing content of the log file will be wiped
/// during the constructor call.
///
/// If [share] is disabled, the file will be locked as long as the handler
/// is active. No other process (section, or even other handler) can write to
/// the file.
///
/// [TracerFileHandlerException] is thrown when the file handling fails.
///
/// If you want to target a directory, use [TracerDirectoryHandler].
class TracerFileHandler extends TracerHandler {
  /// The file to write the logs to.
  final File file;

  /// Whether to enable appending to the existing file.
  ///
  /// If disabled, the existing content of the log file will be wiped once the
  /// object has been initialized.
  final bool append;

  /// Whether to lock the file for the OS.
  ///
  /// **CAUTION**: This may lead to buggy behavior, because both, read and write
  /// access to other processes, are being blocked. Only disable this if
  /// absolutely necessary!
  final bool share;

  RandomAccessFile? _raf;

  TracerFileHandler(this.file, {this.append = true, this.share = true}) {
    file.createSync(recursive: true);
    try {
      _raf = file.openSync(mode: FileMode.writeOnlyAppend);
    } catch (_) {
      throw TracerFileHandlerException("Failed to open file");
    }
    try {
      if (!append) _raf!.truncateSync(0);
      if (!share) _raf!.lockSync(FileLock.exclusive);
    } catch (_) {
      throw TracerFileHandlerException("Failed to lock file");
    }
  }

  @override
  void handle(TracerEventData data) {
    if (_raf == null) return;
    try {
      _raf!.writeStringSync("${data.generatedMessage}\n");
    } catch (_) {
      throw TracerFileHandlerException("Failed to write to file");
    }
  }

  @override
  void dispose() {
    try {
      _raf?.unlockSync();
      _raf?.closeSync();
      _raf = null;
    } catch (_) {}
  }
}
