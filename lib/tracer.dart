/// A modern, simple and easy-to-implement logging framework for Dart.
library;

export 'src/tracer_base.dart';

export 'src/pre/io.dart' if (dart.library.js_interop) 'src/pre/web.dart';

export 'package:stack_trace/src/trace.dart' show Trace;
