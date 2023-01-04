const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("libxml/parser.h");
    @cInclude("libxml/xmlreader.h");
    @cInclude("zip.h");
});

const std = @import("std");
const debug = std.debug;
const ArrayList = std.ArrayList;

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

fn processNode(reader: ?*c.xmlTextReader) !void {
    const name = c.xmlTextReaderConstName(reader);
    const value = c.xmlTextReaderConstValue(reader);
    if (name != null) {
        debug.print("name: {s}\n", .{name});
    } else {
        debug.print("name is null\n", .{});
    }
    if (value != null) {
        debug.print("value: {s}\n", .{value});
    } else {
        debug.print("value is null\n", .{});
    }
    const nodeType = c.xmlTextReaderNodeType(reader);
    // convert to NodeType enum
    printNodeTypeName(@intToEnum(NodeType, nodeType));

    debug.print("\n", .{});
}

// parse the xml and return an array of all text values of <t> elements
fn readSharedStrings(buf: []const u8) ![][]u8 {
    const reader = c.xmlReaderForMemory(buf.ptr, @intCast(c_int, buf.len), null, null, 0);
    defer c.xmlFreeTextReader(reader);
    // check reader != null
    if (reader == null) {
        debug.print("reader is null\n", .{});
        return error.ReaderIsNull;
    }

    // read frootNode identify how many unqiue strings
    var ret = c.xmlTextReaderRead(reader);
    if (ret != 1) {
        debug.print("ret != 1\n", .{});
        return error.ReadFailed;
    }

    // get the uniqueCount attribute
    const uniqueCount = c.xmlTextReaderGetAttribute(reader, "uniqueCount");
    const uniqueCountInt = try std.fmt.parseInt(u32, std.mem.span(uniqueCount), 10);

    // allocate an array of slices
    const sharedStrings = try std.heap.c_allocator.alloc([]u8, uniqueCountInt);

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
                if (@intToEnum(NodeType, nodeType) == NodeType.Text) {
                    const value = c.xmlTextReaderConstValue(reader);
                    if (value != null) {
                        // allocate memory and copy the value to sharedStrings[index]
                        sharedStrings[index] = try std.heap.c_allocator.dupe(u8, std.mem.span(value));
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
        debug.print("error: Failed to open zip file\n", .{});
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
    var buf = try std.heap.c_allocator.alloc(u8, stat.size);
    const read = c.zip_fread(strs, buf.ptr, stat.size);
    if (read != stat.size) {
        debug.print("error: Failed to read {s}\n", .{filename});
        return error.FailedToReadSharedStrings;
    }
    return buf;
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try bw.flush(); // don't forget to flush!

    const sharedStringsBuf = try readZipFileContents("src/test/spreadsheet1/Test_Tags_Spreadsheet.xlsx", "xl/sharedStrings.xml");
    debug.print("{s}\n", .{sharedStringsBuf[0..]});

    const sharedStrings: [][]u8 = try readSharedStrings(sharedStringsBuf);
    debug.print("sharedStrings loaded: {d}\n", .{sharedStrings.len});
    for (sharedStrings) |str| {
        debug.print("{s}\n", .{str});
    }

    // iterate over sharedStrings and print each string

    // const worksheetBuf = try readZipFileContents("src/test/spreadsheet1/Test_Tags_Spreadsheet.xlsx", "xl/worksheets/sheet1.xml");
    // debug.print("{s}\n", .{worksheetBuf[0..]});

    // const reader = c.xmlReaderForMemory(worksheetBuf.ptr, @intCast(c_int, worksheetBuf.len), null, null, 0);
    // defer c.xmlFreeTextReader(reader);
    // // check reader != null
    // if (reader == null) {
    //     debug.print("reader is null\n", .{});
    //     return;
    // }

    // var ret = c.xmlTextReaderRead(reader);
    // while (ret == 1) {
    //     processNode(reader) catch |err| {
    //         debug.print("error: {s}\n", .{err});
    //     };
    //     ret = c.xmlTextReaderRead(reader);
    // }
}

// `zig build test` to run

test "xml read" {
    const ctx = c.xmlNewParserCtxt();
    defer c.xmlFreeParserCtxt(ctx);
    // assert context valid (not null)
    if (ctx == null) {
        debug.print("context is null\n", .{});
        return;
    }

    const reader = c.xmlReaderForFile("src/test/test.xml", null, 0);
    defer c.xmlFreeTextReader(reader);
    // check reader != null
    if (reader == null) {
        debug.print("reader is null\n", .{});
        return;
    }

    var ret = c.xmlTextReaderRead(reader);
    while (ret == 1) {
        const name = c.xmlTextReaderConstName(reader);
        const value = c.xmlTextReaderConstValue(reader);
        if (name != null) {
            debug.print("name: {s}\n", .{name});
        }
        if (value != null) {
            debug.print("value: {s}\n", .{value});
        }
        ret = c.xmlTextReaderRead(reader);
    }
}

// read until we find the first sheet
// var ret = c.xmlTextReaderRead(reader);
// while (ret == 1) {
//     const name = c.xmlTextReaderConstName(reader);
//     if (name != null) {
//         if (std.mem.eql(u8, name, "sheet")) {
//             return reader;
//         }
//     }
//     ret = c.xmlTextReaderRead(reader);
// }
// return error.NoSheetFound;
