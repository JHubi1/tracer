# 0.4.2

- Fixed error character being added to the beginning of `TracerFileHandler`'s log file when using `append`

# 0.4.1

- Reworked `TracerFileHandler`, `shareFile` is now called `share`, and is true by default
- Added `forceUtc` option to `Tracer` object. If true, all dates will be in UTC

# 0.4.0

- Stream is sync again, so no more delay
- `TracerFileHandler` is now called `TracerDirectoryHandler`, for a custom name use `TracerFileHandler`
- `TracerFileHandler` is a new handler that writes to a file specifically

# 0.3.0

- No dependency on `event` anymore, now usable in browser
- Removed `listen` and `ignore` functions, use `add` and `cancel` instead
- Various improvements

# 0.2.0

- Smaller improvements
- Updated regex; first character no longer allowed to be a number

# 0.1.0

- Initial version.
