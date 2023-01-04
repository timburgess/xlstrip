# xlstrip
Strips a column from an Excel xlsx spreadsheet

A simple but *fast* way to extract an Excel column.




### Dependencies

Requires `libsml2-dev` and `libzip-dev` packages

### Build

Requires zig v0.11.0 - see https://ziglang.org/download/

Extract zig tar and add zig dir to your PATH. Then `zig build run`.


### Usage

./zig-out/bin/xlstrip src/test/spreadsheet1/Test_Tags_Spreadsheet.xlsx B
