const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("libxml/parser.h");
    @cInclude("libxml/xmlreader.h");
});

const std = @import("std");

const Color = enum(u32) {
    red = 0xff0000,
    green = 0x00ff00,
    blue = 0x0000ff,
};

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
const parseOptions = c.XML_PARSE_NOBLANKS | c.XML_PARSE_NOCDATA | c.XML_PARSE_NOENT | c.XML_PARSE_NOERROR | c.XML_PARSE_NOWARNING | c.XML_PARSE_NONET;


// print the node type
fn printNodeTypeName(nodeType: NodeType) void {
    switch (nodeType) {
        NodeType.None => std.debug.print("NodeType.None\n", .{}),
        NodeType.Element => std.debug.print("NodeType.Element\n", .{}),
        NodeType.Attribute => std.debug.print("NodeType.Attribute\n", .{}),
        NodeType.Text => std.debug.print("NodeType.Text\n", .{}),
        NodeType.CDATAField => std.debug.print("NodeType.CDATA\n", .{}),
        NodeType.EntityRef => std.debug.print("NodeType.EntityRef\n", .{}),
        NodeType.Entity => std.debug.print("NodeType.Entity\n", .{}),
        NodeType.ProcessingInstruction => std.debug.print("NodeType.PI\n", .{}),
        NodeType.Comment => std.debug.print("NodeType.Comment\n", .{}),
        NodeType.Document => std.debug.print("NodeType.Document\n", .{}),
        NodeType.DocumentType => std.debug.print("NodeType.DocumentType\n", .{}),
        NodeType.DocumentFragment => std.debug.print("NodeType.DocumentFragment\n", .{}),
        NodeType.Notation => std.debug.print("NodeType.Notation\n", .{}),
        NodeType.Whitespace => std.debug.print("NodeType.Whitespace\n", .{}),
        NodeType.SignificantWhitespace => std.debug.print("NodeType.SignificantWhitespace\n", .{}),
        NodeType.EndElement => std.debug.print("NodeType.EndElement\n", .{}),
        NodeType.EndEntity => std.debug.print("NodeType.EndEntity\n", .{}),
        NodeType.XMLDeclaration => std.debug.print("NodeType.XMLDeclaration\n", .{}),
    }
}

fn processNode(reader: ?*c.xmlTextReader) !void {
    const name = c.xmlTextReaderConstName(reader);
    const value = c.xmlTextReaderConstValue(reader);
    if (name != null) {
        std.debug.print("name: {s}\n", .{name});
    } else {
        std.debug.print("name is null\n", .{});
    }
    if (value != null) {
        std.debug.print("value: {s}\n", .{value});
    } else {
        std.debug.print("value is null\n", .{});
    }
    const nodeType = c.xmlTextReaderNodeType(reader);
    // convert to NodeType enum
    printNodeTypeName(@intToEnum(NodeType, nodeType));

    std.debug.print("\n", .{});
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


    const reader = c.xmlReaderForFile("src/test/test.xml", null, parseOptions);
    defer c.xmlFreeTextReader(reader);
    // check reader != null
    if (reader == null) {
        std.debug.print("reader is null\n", .{});
        return;
    }

    var ret = c.xmlTextReaderRead(reader);
    while (ret == 1) {
        processNode(reader) catch |err| {
            std.debug.print("error: {s}\n", .{err});
        };
        ret = c.xmlTextReaderRead(reader);
    }
}

// `zig build test` to run

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }

test "xml read" {
    const ctx = c.xmlNewParserCtxt();
    defer c.xmlFreeParserCtxt(ctx);
    // assert context valid (not null)
    if (ctx == null) {
        std.debug.print("context is null\n", .{});
        return;
    }

    const reader = c.xmlReaderForFile("src/test/test.xml", null, 0);
    defer c.xmlFreeTextReader(reader);
    // check reader != null
    if (reader == null) {
        std.debug.print("reader is null\n", .{});
        return;
    }

    var ret = c.xmlTextReaderRead(reader);
    while (ret == 1) {
        const name = c.xmlTextReaderConstName(reader);
        const value = c.xmlTextReaderConstValue(reader);
        if (name != null) {
            std.debug.print("name: {s}\n", .{name});
        }
        if (value != null) {
            std.debug.print("value: {s}\n", .{value});
        }
        ret = c.xmlTextReaderRead(reader);
    }
}
