pub const c = @cImport({
    @cInclude("libxml/parser.h");
    @cInclude("libxml/xmlreader.h");
    @cInclude("zip.h");
});
