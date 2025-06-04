const c = @cImport({
    @cInclude("libxml/parser.h");
    @cInclude("libxml/xmlreader.h");
    @cInclude("zip.h");
});

const std = @import("std");
const debug = std.debug;
const allocator = std.heap.c_allocator; // use c allocator for now
const fs = std.fs;
const stderr = std.io.getStdErr().writer();
const ArrayList = std.ArrayList;
const parseInt = std.fmt.parseInt;

// enums for NodeType - https://www.gnu.org/software/dotgnu/pnetlib-doc/System/Xml/XmlNodeType.html
const NodeType = enum(c_int) {
    None = 0,
    Element = 1,
    Attribute = 2,
    Text = 3,
    CDATAField = 4, // e.g. <![CDATA[...]]> to escape blocks of text containing characters which would otherwise be regarded as markup.
    EntityRef = 5,
    Entity = 6,
    ProcessingInstruction = 7,
    Comment = 8,
    Document = 9,
    DocumentType = 10,
    DocumentFragment = 11,
    Notation = 12,
    Whitespace = 13,
    SignificantWhitespace = 14,
    EndElement = 15,
    EndEntity = 16,
    XMLDeclaration = 17,

    /// Checks if a given c_int matches `self`.
    pub fn matches(self: NodeType, value: c_int) bool {
        const maybe_node = std.meta.intToEnum(NodeType, value) catch return false;
        return maybe_node == self;
    }
};

// define parser options to ignore whitespace, etc.
const parseOptions = c.XML_PARSE_NOBLANKS | c.XML_PARSE_NOCDATA | c.XML_PARSE_NOENT | c.XML_PARSE_NONET;

// print the node type
fn printNodeTypeName(nodeType: NodeType) void {
    switch (nodeType) {
        NodeType.None => debug.print("NodeType.None\n", .{}),
        NodeType.Element => debug.print("NodeType.Element\n", .{}),
        NodeType.Attribute => debug.print("NodeType.Attribute\n", .{}),
        NodeType.Text => debug.print("NodeType.Text\n", .{}),
        NodeType.CDATAField => debug.print("NodeType.CDATA\n", .{}),
        NodeType.EntityRef => debug.print("NodeType.EntityRef\n", .{}),
        NodeType.Entity => debug.print("NodeType.Entity\n", .{}),
        NodeType.ProcessingInstruction => debug.print("NodeType.PI\n", .{}),
        NodeType.Comment => debug.print("NodeType.Comment\n", .{}),
        NodeType.Document => debug.print("NodeType.Document\n", .{}),
        NodeType.DocumentType => debug.print("NodeType.DocumentType\n", .{}),
        NodeType.DocumentFragment => debug.print("NodeType.DocumentFragment\n", .{}),
        NodeType.Notation => debug.print("NodeType.Notation\n", .{}),
        NodeType.Whitespace => debug.print("NodeType.Whitespace\n", .{}),
        NodeType.SignificantWhitespace => debug.print("NodeType.SignificantWhitespace\n", .{}),
        NodeType.EndElement => debug.print("NodeType.EndElement\n", .{}),
        NodeType.EndEntity => debug.print("NodeType.EndEntity\n", .{}),
        NodeType.XMLDeclaration => debug.print("NodeType.XMLDeclaration\n", .{}),
    }
}

pub fn toCInt(buf_len: usize) c_int {
    const maybe = std.math.cast(c_int, buf_len);
    if (maybe) |value| {
        return value;
    } else {
        std.debug.print("Error: buffer length ({}) exceeds c_int range\n", .{buf_len});
        // TODO: terminate better
        return 0;
    }
}

fn checkColumnNodeForCell(reader: ?*c.xmlTextReader, col: []const u8) !?u32 {
    const nodeName = c.xmlTextReaderConstName(reader);

    // if node is not <c> return
    if (!std.mem.eql(u8, std.mem.span(nodeName), "c")) {
        return null;
    }

    const rAttr = c.xmlTextReaderGetAttribute(reader, "r");
    if (rAttr == null) {
        return null;
    }
    defer c.free(rAttr);
    // debug.print("rAttr: {s}\n", .{rAttr});

    // check if rAttr is a cell of desired column
    if (!std.mem.startsWith(u8, std.mem.span(rAttr), col)) {
        return null;
    }
    // debug.print("rAttr is of col {s}.\n", .{col});

    // advance to next node
    var ret = c.xmlTextReaderRead(reader);
    if (ret == -1) {
        return error.XMLReadError;
    }
    if (ret == 0) { // end of document
        return null;
    }

    const nextNodeName = c.xmlTextReaderConstName(reader);
    if (!std.mem.eql(u8, std.mem.span(nextNodeName), "v")) {
        return null;
    }
    // debug.print("vNodeName is v: {s}\n", .{vNodeName});

    // advance to next (text) node
    ret = c.xmlTextReaderRead(reader);
    if (ret == -1) {
        return error.XMLReadError;
    }
    if (ret == 0) { // end of document
        return null;
    }

    // if next node is Text then read the value
    const nodeType = c.xmlTextReaderNodeType(reader);
    // if (@intToEnum(NodeType, nodeType) != NodeType.Text) {
    if (!NodeType.Text.matches(nodeType)) {
        // unsure what this node is so return
        return null;
    }

    const value = c.xmlTextReaderConstValue(reader);
    if (value == null) {
        return null;
    }

    return try parseInt(u32, std.mem.span(value), 10);
}

// function to find all <c> nodes that have an attribute of r that matches the column
// e.g. r="B1", r="B2", etc.
//
//   <sheetData>
//    <row r="1" spans="1:16">
//      <c r="B1" t="s">
//        <v>22</v>
//      </c>
//      <c r="C1" t="s">
//        <v>0</v>
//      </c>
//
// for each of these nodes, read the <v> text node and lookup the string in sharedStrings
//
fn readSheet(buf: []const u8, col: []const u8, sharedStrings: [][]u8) !void {
    const reader = c.xmlReaderForMemory(buf.ptr, toCInt(buf.len), null, null, 0);
    if (reader == null) {
        return error.ReaderIsNull;
    }
    defer c.xmlFreeTextReader(reader);

    var ret = c.xmlTextReaderRead(reader);
    while (ret == 1) {
        const sharedIndex = try checkColumnNodeForCell(reader, col);
        if (sharedIndex != null) {
            debug.print("{s}\n", .{sharedStrings[sharedIndex.?]});
        }
        ret = c.xmlTextReaderRead(reader);
    }
}

// parse the xml and return an array of all text values of <t> elements
fn readSharedStrings(buf: []const u8) ![][]u8 {
    // usize to c_int for xmlReaderforMemory
    const reader = c.xmlReaderForMemory(buf.ptr, toCInt(buf.len), null, null, 0);
    defer c.xmlFreeTextReader(reader);
    if (reader == null) {
        return error.ReaderIsNull;
    }

    // read frootNode identify how many unique strings
    var ret = c.xmlTextReaderRead(reader);
    if (ret != 1) {
        return error.ReadFailed;
    }

    // get the uniqueCount attribute
    const uniqueCount = c.xmlTextReaderGetAttribute(reader, "uniqueCount");
    const uniqueCountInt = try parseInt(u32, std.mem.span(uniqueCount), 10);

    // allocate an array of slices
    const sharedStrings = try allocator.alloc([]u8, uniqueCountInt);

    // read the remaining nodes
    var index: u32 = 0;
    ret = c.xmlTextReaderRead(reader);
    while (ret == 1) {
        const nodeName = c.xmlTextReaderConstName(reader);
        // if node is <t> then read the next node (text node)
        if (std.mem.eql(u8, std.mem.span(nodeName), "t")) {
            // read the next text node
            ret = c.xmlTextReaderRead(reader);
            if (ret == 1) {
                const nodeType = c.xmlTextReaderNodeType(reader);
                if (NodeType.Text.matches(nodeType)) {
                    const value = c.xmlTextReaderConstValue(reader);
                    if (value != null) {
                        // allocate memory and copy the value to sharedStrings[index]
                        sharedStrings[index] = try allocator.dupe(u8, std.mem.span(value));
                        index += 1;
                    }
                }
            }
        }
        ret = c.xmlTextReaderRead(reader);
    }

    return sharedStrings;
}

// accepts a path to the zip file and returns a buffer containing the contents of internal file
fn readZipFileContents(path: [*c]const u8, filename: [*c]const u8) ![]u8 {
    const archive = c.zip_open(path, c.ZIP_RDONLY, null);
    defer _ = c.zip_close(archive);
    if (archive == null) {
        debug.print("error: Failed to open zip file {s}\n", .{filename});
        return error.FailedToOpenZipFile;
    }

    var stat: c.zip_stat_t = undefined;
    // var i: u64 = 0;
    // while (true) {
    //     const ret = c.zip_stat_index(archive, i, 0, &stat);
    //     if (ret != 0) {
    //         break;
    //     }
    //     debug.print("name: {s}\n", .{stat.name});
    //     i += 1;
    // }

    // open filename and stat size
    const ret = c.zip_stat(archive, filename, 0, &stat);
    if (ret != 0) {
        debug.print("error: Failed to open {s}\n", .{filename});
        return error.FailedToOpenSharedStrings;
    }

    const strs = c.zip_fopen(archive, filename, 0);
    defer _ = c.zip_fclose(strs);
    if (strs == null) {
        debug.print("error: Failed to open {s}\n", .{filename});
        return error.FailedToOpenSharedStrings;
    }

    // load file contents into buffer
    const buf = try allocator.alloc(u8, stat.size);
    const read = c.zip_fread(strs, buf.ptr, stat.size);
    if (read != stat.size) {
        debug.print("error: Failed to read {s}\n", .{filename});
        return error.FailedToReadSharedStrings;
    }
    return buf;
}

fn fileExists(filepath: []const u8) bool {
    var file = fs.cwd().openFile(filepath, .{ .mode = .read_only }) catch return false;
    file.close();
    return true;
}

//
// commandline args should be 1) xlsx file path 2) column to read e.g. B
// e.g. ./xlstrip "src/test/spreadsheet1/Test_Tags_Spreadsheet.xlsx" "B"
//
pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        try stderr.print("error: Expected 2 arguments, got {d}\n", .{args.len - 1});
        return;
    }

    const spreadsheetPath = args[1];
    if (!fileExists(spreadsheetPath)) {
        debug.print("error: File {s} does not exist\n", .{spreadsheetPath});
        return;
    }

    const col = args[2];

    // load all strings used in the spreadsheet (aka 'shared strings')
    const sharedStringsBuf = try readZipFileContents(spreadsheetPath, "xl/sharedStrings.xml");
    // debug.print("{s}\n", .{sharedStringsBuf[0..]});

    const sharedStrings: [][]u8 = try readSharedStrings(sharedStringsBuf);
    defer allocator.free(sharedStrings);
    defer for (sharedStrings) |str| allocator.free(str);

    // for (sharedStrings) |str| {
    //     debug.print("{s}\n", .{str});
    // }

    // load worksheet
    const worksheetBuf = try readZipFileContents(spreadsheetPath, "xl/worksheets/sheet1.xml");
    // debug.print("{s}\n", .{worksheetBuf[0..]});

    // Call function to find all <c> nodes that have an attribute of the required column
    // For each of these nodes, read the value and lookup the string in sharedStrings
    // and print the string
    try readSheet(worksheetBuf, col, sharedStrings);
}

// pub fn main() !void {
//     // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
//     std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

//     // stdout is for the actual output of your application, for example if you
//     // are implementing gzip, then only the compressed bytes should be sent to
//     // stdout, not any debugging messages.
//     const stdout_file = std.io.getStdOut().writer();
//     var bw = std.io.bufferedWriter(stdout_file);
//     const stdout = bw.writer();

//     try stdout.print("Run `zig build test` to run the tests.\n", .{});

//     try bw.flush(); // Don't forget to flush!
// }

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }

// test "use other module" {
//     try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
// }

// test "fuzz example" {
//     const Context = struct {
//         fn testOne(context: @This(), input: []const u8) anyerror!void {
//             _ = context;
//             // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
//             try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
//         }
//     };
//     try std.testing.fuzz(Context{}, Context.testOne, .{});
// }
