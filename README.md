# Tracer

A modern, simple and easy-to-implement logging framework for Dart.

![example usage](https://github.com/JHubi1/tracer/raw/main/assets/img1.png)

> The package should be working with all Flutter platforms, including web. It has also been tested with pure Dart.

## Usage

The base Tracer object can be created by calling its constructor just like that:

```dart
var t = Tracer("example");
```

The first key is called 'section' and used to identify this logger. The string can be anything you want, it doesn't affect functionality.

You can then just call one of the log functions:

```dart
t.debug("This is a debug message");
t.info("This is an info message");
t.warn("This is a warning message");
t.error("This is an error message");
t.fatal("This is a fatal message");
```

In case you've followed the steps, you might have already noticed that nothing happens when you call those functions. That is, because you also have to add a handler that can do something with the log events. Read more under [handlers](#handlers).

There are also a few other things you can do with the logging methods. To learn more, read [extended logging](#extended-logging).

By default, logs with the debug level will be hidden. To set a custom minimum level, set `logLevel` of the Tracer constructor to a value to TracerLevel, like `TracerLevel.info` (the default).

## Handlers

This library itself does nothing with your sent log messages. You have to specify what happens yourself.

Now don't worry, you don't have to reinvent the wheel; the package has a few build in output handlers that can help you.

To embed a handler, just add the argument to the Trace object's constructor:

```dart
var tracer = Tracer("example", handlers: [
    TracerConsoleHandler(),
    TracerFileHandler(Directory("./logs"))
]);
```

The list will be processed from top to bottom. The first handler will be evaluated the first, and so on. The two most prominent integrated handlers are:

1. `TracerConsoleHandler`
   - This is the handler you probably will use the most often. It outputs the generated logs to the systems terminal.
   - The output will be colored by default. To disable that, set `useColors` to false.
   - It uses Dart's `print` function by default, so it is fully compatible with Flutter platform output. To use normal `stdout` and `stderr`, set `useStderr` to true.
2. `TracerFileHandler`
   - This handler outputs to a file. By default, it creates a new file per day in the given directory.
   - To use a fixed name set the attribute `customName` to a valid file name string.
   - The passed directory will be created automatically if it doesn't exist. It should be a valid path though.

### Custom handler

Creating your own handler is straight forward. You just have to create a new class that extends the predefined `TracerHandler` class.

```dart
class TracerTestHandler extends TracerHandler {
    @override
    void handle(TracerEventData data) {
        print(data.body);
    }
}
```

After that, you can register it as a handler in the same way you register pre defined ones.

```dart
var tracer = Tracer("example", handlers: [
    TracerTestHandler()
]);
```

### Alternative

If you don't need to get notified whenever a new log event is created, you may not want to create a whole handler and keep track of the full log history yourself.

Luckily, you're able to access the history by just reading a value of your Tracer object. You can either access a text representation, or a list of all previous `TracerEventData`s.

```dart
tracer.logs             // the list of TracerEventData
tracer.logsGenerated    // string representation
```

## Filters

Filters are build very similarly to handlers. They are asked, even before the log event is fired, if it should be handled. This can be useful if a third party module controls the logger, but you don't want to output everting.

There aren't any build in filters, if you need one, you have to create one yourself.

To start, create a new class that extends the build in `TracerFilter` class with your implementation:

```dart
class TracerTestFilter extends TracerFilter {
    @override
    bool handle(TracerEventData data) {
        return data.body.contains("happy");
    }
}
```

The `handle` function this time has to return a bool value that determines if the event will be handled. If false, the event will be ignored.

To add your filter, you have to add it to the constructor, just like that:

```dart
var tracer = Tracer("example", filters: [
    TracerTestFilter()
]);
```

The filters will be handled from top to bottom. If one filter returns false, the following ones won't be evaluated.

## Extended logging

You can also add descriptions, errors and stack traces to your logging requests.

To use a description, just add the `description` attribute to the log function's tool call. Multi line strings are also supported.

```dart
t.info("This will have a description", description: "I AM THE DESCRIPTION!");
```

```log
[2024-10-20 17:12:37 +0200] Info : example: This will have a description
                            |> I AM THE DESCRIPTION!
```

To add error / exception and stack trace reporting, you can add the attributes `error` and `stack` to the function call. This is only available for level `TracerLevel.warn` and higher.

```dart
try {
    throw Exception("This is a stack trace");
} catch (e, s) {
    t.fatal("This is an error",
        error: e, stack: s);
}
```

```log
[2024-10-20 17:59:21 +0200] Fatal: example: This is a stack trace
                            |- Exception: This is an exception
                            |- example\tracer_example.dart 31:5  main
```

## Ideas and issues

Did you find an issue with a function of this project? Did you have an idea for a new feature? Feel free to [open new issue](https://github.com/JHubi1/tracer/issues).

## Contribution

I'm open to contributions. But please ask beforehand. If you see a feature request, write a comment to it and show your interest. I'll assign you.

If you have a new idea, please open a new feature request issue. You can implement the idea yourself (tick the checkbox).
