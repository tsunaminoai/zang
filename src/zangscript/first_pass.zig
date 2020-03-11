const std = @import("std");
const Parser = @import("common.zig").Parser;
const Source = @import("common.zig").Source;
const fail = @import("common.zig").fail;
const Token = @import("tokenizer.zig").Token;
const TokenType = @import("tokenizer.zig").TokenType;
const SourceLocation = @import("tokenizer.zig").SourceLocation;
const Expression = @import("second_pass.zig").Expression;

pub const ResolvedParamType = enum {
    boolean,
    number,
};

pub const BuiltinModule = enum {
    pulse_osc,
    tri_saw_osc,
};

pub const ResolvedFieldType = union(enum) {
    builtin_module: BuiltinModule,
    script_module: usize, // index into module_defs
};

// this is separate because it's also used for builtin modules
pub const ModuleParam = struct {
    name: []const u8,
    param_type: ResolvedParamType,
};

pub const ModuleParamDecl = struct {
    name: []const u8,
    type_token: Token,
    type_name: []const u8, // UNRESOLVED type name
};

pub const ModuleFieldDecl = struct {
    name: []const u8,
    type_token: Token,
    type_name: []const u8, // UNRESOLVED type name
    resolved_type: ResolvedFieldType,
};

pub const ModuleDef = struct {
    name: []const u8,
    param_decls: std.ArrayList(ModuleParamDecl),
    // in between the first and second passes, we'll resolve params from param_decls. (it's undefined during the first pass.)
    params: []const ModuleParam,
    fields: std.ArrayList(ModuleFieldDecl),
    begin_token: usize,
    end_token: usize,
    expression: Expression,
};

pub const FirstPassResult = struct {
    module_defs: []ModuleDef,
};

pub const FirstPass = struct {
    parser: Parser,
    module_defs: std.ArrayList(ModuleDef),

    pub fn init(
        source: Source,
        tokens: []const Token,
        allocator: *std.mem.Allocator,
    ) FirstPass {
        return .{
            .parser = .{
                .source = source,
                .tokens = tokens,
                .i = 0,
            },
            .module_defs = std.ArrayList(ModuleDef).init(allocator),
        };
    }
};

pub fn defineModule(self: *FirstPass, allocator: *std.mem.Allocator) !void {
    const module_name = try self.parser.expectIdentifier();

    const ctoken = try self.parser.expect();
    if (ctoken.tt != .sym_colon) {
        return fail(self.parser.source, ctoken, "expected `:`, found `%`", .{ctoken});
    }

    var module_def: ModuleDef = .{
        .name = module_name,
        .param_decls = std.ArrayList(ModuleParamDecl).init(allocator),
        .params = undefined,
        .fields = std.ArrayList(ModuleFieldDecl).init(allocator),
        .begin_token = undefined,
        .end_token = undefined,
        .expression = undefined,
    };

    while (true) {
        var token = try self.parser.expect();
        switch (token.tt) {
            .kw_begin => break,
            .kw_param => {
                // param declaration
                const field_name = try self.parser.expectIdentifier();
                const type_token = try self.parser.expect();
                const type_name = switch (type_token.tt) {
                    .identifier => |identifier| identifier,
                    else => return fail(self.parser.source, type_token, "expected param type, found `%`", .{type_token}),
                };
                token = try self.parser.expect();
                if (token.tt != .sym_semicolon) {
                    return fail(self.parser.source, token, "expected `;`, found `%`", .{token});
                }
                try module_def.param_decls.append(.{
                    .name = field_name,
                    .type_token = type_token,
                    .type_name = type_name,
                });
            },
            .identifier => |identifier| {
                // field declaration
                const field_name = identifier;
                const type_token = try self.parser.expect();
                const type_name = switch (type_token.tt) {
                    .identifier => |identifier2| identifier2,
                    else => return fail(self.parser.source, type_token, "expected field type, found `%`", .{type_token}),
                };
                const ctoken2 = try self.parser.expect();
                if (ctoken2.tt != .sym_semicolon) {
                    return fail(self.parser.source, ctoken2, "expected `;`, found `%`", .{ctoken2});
                }
                try module_def.fields.append(.{
                    .name = field_name,
                    .type_token = type_token,
                    .type_name = type_name,
                    .resolved_type = undefined,
                });
            },
            else => {
                return fail(
                    self.parser.source,
                    token,
                    "expected field declaration or `begin`, found `%`",
                    .{token},
                );
            },
        }
    }

    // skip paint block
    module_def.begin_token = self.parser.i;
    while (true) {
        const token = try self.parser.expect();
        switch (token.tt) {
            .kw_end => break,
            else => {},
        }
    }
    module_def.end_token = self.parser.i;

    try self.module_defs.append(module_def);
}

pub fn firstPass(
    source: Source,
    tokens: []const Token,
    allocator: *std.mem.Allocator,
) !FirstPassResult {
    var self = FirstPass.init(source, tokens, allocator);

    errdefer {
        // FIXME deinit fields
        self.module_defs.deinit();
    }

    while (self.parser.next()) |token| {
        switch (token.tt) {
            .kw_def => try defineModule(&self, allocator),
            else => return fail(self.parser.source, token, "expected `def` or end of file, found `%`", .{token}),
        }
    }

    var module_defs = self.module_defs.toOwnedSlice();

    try resolveTypes(source, module_defs, allocator);

    return FirstPassResult{
        .module_defs = module_defs,
    };
}

// this is the 1 1/2 pass
fn resolveParamType(source: Source, param: ModuleParamDecl) !ResolvedParamType {
    if (std.mem.eql(u8, param.type_name, "boolean")) {
        return .boolean;
    }
    if (std.mem.eql(u8, param.type_name, "number")) {
        return .number;
    }
    // TODO if a module was referenced, be nice and recognize that but say it's not allowed
    return fail(source, param.type_token, "could not resolve param type `%`", .{param.type_token});
}

fn resolveFieldType(
    source: Source,
    module_defs: []const ModuleDef,
    current_module_index: usize,
    field: *const ModuleFieldDecl,
) !ResolvedFieldType {
    // TODO if a type like boolean/number was referenced, be nice and recognize that but say it's not allowed
    if (std.mem.eql(u8, field.type_name, "PulseOsc")) {
        return ResolvedFieldType{ .builtin_module = .pulse_osc };
    }
    if (std.mem.eql(u8, field.type_name, "TriSawOsc")) {
        return ResolvedFieldType{ .builtin_module = .tri_saw_osc };
    }
    for (module_defs) |*module_def2, j| {
        if (std.mem.eql(u8, field.type_name, module_def2.name)) {
            if (j == current_module_index) {
                // FIXME - do a full circular dependency detection
                return fail(source, field.type_token, "cannot use self as field", .{});
            }
            return ResolvedFieldType{ .script_module = j };
        }
    }
    return fail(source, field.type_token, "could not resolve field type `%`", .{field.type_token});
}

fn resolveTypes(source: Source, module_defs: []ModuleDef, allocator: *std.mem.Allocator) !void {
    for (module_defs) |*module_def, i| {
        module_def.params = try allocator.alloc(ModuleParam, module_def.param_decls.span().len); // FIXME never freed
        for (module_def.param_decls.span()) |param_decl, j| {
            module_def.params[j] = .{
                .name = param_decl.name,
                .param_type = try resolveParamType(source, param_decl),
            };
        }
        for (module_def.fields.span()) |*field| {
            field.resolved_type = try resolveFieldType(source, module_defs, i, field);
        }
    }
}
