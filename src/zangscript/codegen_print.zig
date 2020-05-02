const std = @import("std");
const PrintHelper = @import("print_helper.zig").PrintHelper;
const CodegenModuleState = @import("codegen.zig").CodegenModuleState;
const ExpressionResult = @import("codegen.zig").ExpressionResult;
const BufferDest = @import("codegen.zig").BufferDest;
const FloatDest = @import("codegen.zig").FloatDest;

const State = struct {
    codegen_state: *const CodegenModuleState,
    helper: PrintHelper,

    pub fn print(self: *State, comptime fmt: []const u8, args: var) !void {
        try self.helper.print(self, fmt, args);
    }

    pub fn printArgValue(self: *State, comptime arg_format: []const u8, arg: var) !void {
        if (comptime std.mem.eql(u8, arg_format, "buffer_dest")) {
            try self.printBufferDest(arg);
        } else if (comptime std.mem.eql(u8, arg_format, "float_dest")) {
            try self.printFloatDest(arg);
        } else if (comptime std.mem.eql(u8, arg_format, "expression_result")) {
            try self.printExpressionResult(arg);
        } else {
            @compileError("unknown arg_format: \"" ++ arg_format ++ "\"");
        }
    }

    fn printExpressionResult(self: *State, result: ExpressionResult) std.os.WriteError!void {
        switch (result) {
            .nothing => unreachable,
            .temp_buffer => |temp_ref| try self.print("temp{usize}", .{temp_ref.index}),
            .temp_float => |temp_ref| try self.print("temp_float{usize}", .{temp_ref.index}),
            .literal_boolean => |value| try self.print("{bool}", .{value}),
            .literal_number => |value| try self.print("{number_literal}", .{value}),
            .literal_enum_value => |v| {
                try self.print("'{str}'", .{v.label});
                if (v.payload) |payload| {
                    try self.print("({expression_result})", .{payload.*});
                }
            },
            .self_param => |i| {
                const module = self.codegen_state.modules[self.codegen_state.module_index];
                try self.print("params.{str}", .{module.params[i].name});
            },
        }
    }

    fn printFloatDest(self: *State, dest: FloatDest) !void {
        try self.print("temp_float{usize}", .{dest.temp_float_index});
    }

    fn printBufferDest(self: *State, dest: BufferDest) !void {
        switch (dest) {
            .temp_buffer_index => |i| try self.print("temp{usize}", .{i}),
            .output_index => |i| try self.print("output{usize}", .{i}),
        }
    }
};

pub fn printBytecode(codegen_state: *const CodegenModuleState) !void {
    const stderr_file = std.io.getStdErr();
    var stderr_file_out_stream = stderr_file.outStream();

    var self: State = .{
        .codegen_state = codegen_state,
        .helper = PrintHelper.init(&stderr_file_out_stream),
    };
    defer self.helper.deinit();

    const self_module = codegen_state.modules[codegen_state.module_index];

    try self.print("module '{str}'\n", .{self_module.name});
    try self.print("    num_temp_buffers: {usize}\n", .{codegen_state.temp_buffers.finalCount()});
    try self.print("    num_temp_floats: {usize}\n", .{codegen_state.temp_floats.finalCount()});
    try self.print("bytecode:\n", .{});
    for (codegen_state.instructions.items) |instr| {
        try self.print("    ", .{});
        switch (instr) {
            .copy_buffer => |x| {
                try self.print("{buffer_dest} = {expression_result}\n", .{ x.out, x.in });
            },
            .float_to_buffer => |x| {
                try self.print("{buffer_dest} = {expression_result}\n", .{ x.out, x.in });
            },
            .cob_to_buffer => |x| {
                const module = self.codegen_state.modules[self.codegen_state.module_index];
                try self.print("{buffer_dest} = COB_TO_BUFFER params.{str}\n", .{ x.out, module.params[x.in_self_param].name });
            },
            .negate_float_to_float => |x| {
                try self.print("{float_dest} = NEGATE_FLOAT_TO_FLOAT {expression_result}\n", .{ x.out, x.a });
            },
            .negate_buffer_to_buffer => |x| {
                try self.print("{buffer_dest} = NEGATE_BUFFER_TO_BUFFER {expression_result}\n", .{ x.out, x.a });
            },
            .arith_float_float => |x| {
                try self.print("{float_dest} = ARITH_FLOAT_FLOAT({auto}) {expression_result} {expression_result}\n", .{ x.out, x.op, x.a, x.b });
            },
            .arith_float_buffer => |x| {
                try self.print("{buffer_dest} = ARITH_FLOAT_BUFFER({auto}) {expression_result} {expression_result}\n", .{ x.out, x.op, x.a, x.b });
            },
            .arith_buffer_float => |x| {
                try self.print("{buffer_dest} = ARITH_BUFFER_FLOAT({auto}) {expression_result} {expression_result}\n", .{ x.out, x.op, x.a, x.b });
            },
            .arith_buffer_buffer => |x| {
                try self.print("{buffer_dest} = ARITH_BUFFER_BUFFER({auto}) {expression_result} {expression_result}\n", .{ x.out, x.op, x.a, x.b });
            },
            .call => |call| {
                const field_module_index = codegen_state.resolved_fields[call.field_index];
                const callee_module = codegen_state.modules[field_module_index];
                try self.print("{buffer_dest} = CALL #{usize}({str})\n", .{ call.out, call.field_index, callee_module.name });
                try self.print("        temps: [", .{});
                for (call.temps) |temp, i| {
                    if (i > 0) try self.print(", ", .{});
                    try self.print("temp{usize}", .{temp});
                }
                try self.print("]\n", .{});
                for (call.args) |arg, i| {
                    try self.print("        {str} = {expression_result}\n", .{ callee_module.params[i].name, arg });
                }
            },
            .delay_begin => |delay_begin| {
                try self.print("DELAY_BEGIN (feedback provided at temps[{usize}])\n", .{delay_begin.feedback_temp_buffer_index});
            },
            .delay_end => |delay_end| {
                //try self.print("{buffer_dest} = DELAY_END {expression_result}\n", .{delay_end.out,delay_end.inner_value}); // FIXME
                try self.print("{buffer_dest} = DELAY_END\n", .{delay_end.out});
            },
        }
    }
    try self.print("\n", .{});
}