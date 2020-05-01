const std = @import("std");
const fail = @import("fail.zig").fail;

pub const Source = struct {
    filename: []const u8,
    contents: []const u8,

    pub fn getString(self: Source, source_range: SourceRange) []const u8 {
        return self.contents[source_range.loc0.index..source_range.loc1.index];
    }
};

pub const SourceLocation = struct {
    // which line in the source file (starts at 0)
    line: usize,
    // byte offset into source file.
    // the column can be found by searching backward for a newline
    index: usize,
};

pub const SourceRange = struct {
    loc0: SourceLocation,
    loc1: SourceLocation,
};

pub const TokenType = union(enum) {
    illegal,
    end_of_file,
    uppercase_name,
    lowercase_name,
    number: f32,
    enum_value,
    sym_asterisk,
    sym_colon,
    sym_comma,
    sym_dbl_asterisk,
    sym_equals,
    sym_left_paren,
    sym_minus,
    sym_plus,
    sym_right_paren,
    sym_slash,
    kw_begin,
    kw_def,
    kw_delay,
    kw_end,
    kw_false,
    kw_feedback,
    kw_let,
    kw_out,
    kw_true,
};

pub const Token = struct {
    source_range: SourceRange,
    tt: TokenType,
};

pub const Tokenizer = struct {
    source: Source,
    loc: SourceLocation,

    pub fn init(source: Source) Tokenizer {
        return .{
            .source = source,
            .loc = .{ .line = 0, .index = 0 },
        };
    }

    fn makeToken(loc0: SourceLocation, loc1: SourceLocation, tt: TokenType) Token {
        return .{
            .source_range = .{ .loc0 = loc0, .loc1 = loc1 },
            .tt = tt,
        };
    }

    pub fn next(self: *Tokenizer) !Token {
        const src = self.source.contents;

        var loc = self.loc;
        defer self.loc = loc;

        while (true) {
            while (loc.index < src.len and isWhitespace(src[loc.index])) {
                if (src[loc.index] == '\r') {
                    loc.index += 1;
                    if (loc.index == src.len or src[loc.index] != '\n') {
                        loc.line += 1;
                        continue;
                    }
                }
                if (src[loc.index] == '\n') {
                    loc.line += 1;
                }
                loc.index += 1;
            }
            if (loc.index + 2 < src.len and src[loc.index] == '/' and src[loc.index + 1] == '/') {
                while (loc.index < src.len and src[loc.index] != '\r' and src[loc.index] != '\n') {
                    loc.index += 1;
                }
                continue;
            }
            if (loc.index == src.len) {
                return makeToken(loc, loc, .end_of_file);
            }
            const start = loc;
            inline for (@typeInfo(TokenType).Union.fields) |field| {
                if (comptime std.mem.startsWith(u8, field.name, "sym_")) {
                    const tt = @unionInit(TokenType, field.name, {});
                    const symbol_string = getSymbolString(tt);
                    if (std.mem.startsWith(u8, src[loc.index..], symbol_string)) {
                        loc.index += symbol_string.len;
                        return makeToken(start, loc, tt);
                    }
                }
            }
            if (src[loc.index] == '\'') {
                loc.index += 1;
                const start2 = loc;
                while (true) {
                    if (loc.index == src.len or src[loc.index] == '\r' or src[loc.index] == '\n') {
                        const sr: SourceRange = .{ .loc0 = start, .loc1 = loc };
                        return fail(self.source, sr, "expected closing `'`, found end of line", .{});
                    }
                    if (src[loc.index] == '\'') {
                        break;
                    }
                    loc.index += 1;
                }
                if (loc.index == start2.index) {
                    // the reason i catch this here is that the quotes are not included in the
                    // enum literal token. and if i let an empty value through, there will be
                    // no characters to underline in further compile errors. whereas here we
                    // know about the quote characters and can include them in the underlining
                    loc.index += 1;
                    const sr: SourceRange = .{ .loc0 = start, .loc1 = loc };
                    return fail(self.source, sr, "enum literal cannot be empty", .{});
                }
                const token = makeToken(start2, loc, .enum_value);
                loc.index += 1;
                return token;
            }
            if (getNumber(src[loc.index..])) |len| {
                loc.index += len;
                const n = std.fmt.parseFloat(f32, src[start.index..loc.index]) catch {
                    const sr: SourceRange = .{ .loc0 = start, .loc1 = loc };
                    return fail(self.source, sr, "malformatted number", .{});
                };
                return makeToken(start, loc, .{ .number = n });
            }
            if (isUppercase(src[loc.index])) {
                loc.index += 1;
                while (loc.index < src.len and isValidNameTailChar(src[loc.index])) {
                    loc.index += 1;
                }
                return makeToken(start, loc, .uppercase_name);
            }
            if (isLowercase(src[loc.index])) {
                loc.index += 1;
                while (loc.index < src.len and isValidNameTailChar(src[loc.index])) {
                    loc.index += 1;
                }
                const string = src[start.index..loc.index];
                inline for (@typeInfo(TokenType).Union.fields) |field| {
                    if (comptime std.mem.startsWith(u8, field.name, "kw_")) {
                        const tt = @unionInit(TokenType, field.name, {});
                        if (std.mem.eql(u8, string, getKeywordString(tt))) {
                            return makeToken(start, loc, tt);
                        }
                    }
                }
                return makeToken(start, loc, .lowercase_name);
            }
            loc.index += 1;
            return makeToken(start, loc, .illegal);
        }
    }

    pub fn peek(self: *Tokenizer) !Token {
        const loc = self.loc;
        defer self.loc = loc;

        return try self.next();
    }

    pub fn failExpected(self: *Tokenizer, desc: []const u8, found: Token) error{Failed} {
        if (found.tt == .end_of_file) {
            return fail(self.source, found.source_range, "expected #, found end of file", .{desc});
        } else {
            return fail(self.source, found.source_range, "expected #, found `<`", .{desc});
        }
    }

    // use this for requiring the next token to be a specific symbol or keyword
    pub fn expectNext(self: *Tokenizer, tt: var) !void {
        const token = try self.next();
        if (token.tt == tt) return;
        const desc = if (comptime std.mem.startsWith(u8, @tagName(tt), "sym_"))
            "`" ++ getSymbolString(tt) ++ "`"
        else if (comptime std.mem.startsWith(u8, @tagName(tt), "kw_"))
            "`" ++ getKeywordString(tt) ++ "`"
        else
            unreachable;
        return self.failExpected(desc, token);
    }
};

inline fn isWhitespace(ch: u8) bool {
    return ch == ' ' or ch == '\t' or ch == '\r' or ch == '\n';
}

inline fn isLowercase(ch: u8) bool {
    return ch >= 'a' and ch <= 'z';
}

inline fn isUppercase(ch: u8) bool {
    return ch >= 'A' and ch <= 'Z';
}

inline fn isValidNameTailChar(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9') or ch == '_';
}

fn getNumber(string: []const u8) ?usize {
    if (string[0] >= '0' and string[0] <= '9') {
        var i: usize = 1;
        while (i < string.len and ((string[i] >= '0' and string[i] <= '9') or string[i] == '.')) {
            i += 1;
        }
        return i;
    }
    return null;
}

fn getSymbolString(tt: TokenType) []const u8 {
    switch (tt) {
        .sym_dbl_asterisk => return "**",
        .sym_asterisk => return "*",
        .sym_colon => return ":",
        .sym_comma => return ",",
        .sym_equals => return "=",
        .sym_left_paren => return "(",
        .sym_minus => return "-",
        .sym_plus => return "+",
        .sym_right_paren => return ")",
        .sym_slash => return "/",
        else => unreachable,
    }
}

fn getKeywordString(tt: TokenType) []const u8 {
    switch (tt) {
        .kw_begin => return "begin",
        .kw_def => return "def",
        .kw_delay => return "delay",
        .kw_end => return "end",
        .kw_false => return "false",
        .kw_feedback => return "feedback",
        .kw_let => return "let",
        .kw_out => return "out",
        .kw_true => return "true",
        else => unreachable,
    }
}
