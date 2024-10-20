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
/// All of the above can be overwritten using [customName]. If it it set, the
/// filename is not variable and just that value.
class TracerFileHandler extends TracerHandler {
  /// The directory to create the log files in.
  final Directory dir;

  /// Whether to enable appending to the existing file. If disabled, the
  /// existing content of the log file will be wiped once the first log from
  /// this [Tracer] instance is created.
  final bool append;

  /// Whether not to add a suffix to the log file name.
  final bool shareFile;

  /// Whether to se the current date for the log file. If disabled `latest.log`
  /// is used.
  final bool useDate;

  /// A custom name used for the log file. This has to include a file ending,
  /// `.log` is recommended.
  final String? customName;

  bool _handledOverwrite = false;

  String _getFileName(TracerEventData data) {
    var name = "latest.log";
    if (useDate) {
      name = "${DateFormat("yyyy-MM-dd").format(data.timestamp)}.log";
    }
    if (!shareFile) name = "${data.section}.$name";
    if (customName != null) name = customName!;
    return name;
  }

  TracerFileHandler(this.dir,
      {this.append = true,
      this.shareFile = true,
      this.useDate = true,
      this.customName}) {
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
