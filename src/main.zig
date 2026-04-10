const std = @import("std");

// FLUX Bytecode VM — Zig Implementation
const Op = enum(u8) {
    MOV  = 0x01,
    IADD = 0x08,
    ISUB = 0x09,
    IMUL = 0x0A,
    IDIV = 0x0B,
    INC  = 0x0E,
    DEC  = 0x0F,
    PUSH = 0x10,
    POP  = 0x11,
    CMP  = 0x2D,
    MOVI = 0x2B,
    JZ   = 0x2E,
    JNZ  = 0x06,
    JMP  = 0x07,
    HALT = 0x80,
    _,
};

pub const FluxVM = struct {
    gp: [16]i32 = [_]i32{0} ** 16,
    pc: usize = 0,
    halted: bool = false,
    cycles: u32 = 0,
    stack: [1024]i32 = [_]i32{0} ** 1024,
    sp: usize = 0,
    bytecode: []const u8,

    fn fetchU8(self: *FluxVM) u8 {
        const v = self.bytecode[self.pc];
        self.pc += 1;
        return v;
    }

    fn fetchI16(self: *FluxVM) i16 {
        const lo: i16 = @intCast(self.bytecode[self.pc]);
        const hi: i16 = @intCast(self.bytecode[self.pc + 1]);
        self.pc += 2;
        return lo | (hi << 8);
    }

    pub fn execute(self: *FluxVM) u32 {
        self.halted = false;
        self.cycles = 0;
        while (!self.halted and self.pc < self.bytecode.len and self.cycles < 10_000_000) {
            const raw_op = self.fetchU8();
            const op: Op = @enumFromInt(raw_op);
            self.cycles += 1;
            switch (op) {
                .HALT => self.halted = true,
                .MOV => { const d = self.fetchU8(); const s = self.fetchU8(); self.gp[d] = self.gp[s]; },
                .MOVI => { const d = self.fetchU8(); const v = self.fetchI16(); self.gp[d] = v; },
                .IADD => { const d = self.fetchU8(); const a = self.fetchU8(); const b = self.fetchU8(); self.gp[d] = self.gp[a] + self.gp[b]; },
                .ISUB => { const d = self.fetchU8(); const a = self.fetchU8(); const b = self.fetchU8(); self.gp[d] = self.gp[a] - self.gp[b]; },
                .IMUL => { const d = self.fetchU8(); const a = self.fetchU8(); const b = self.fetchU8(); self.gp[d] = self.gp[a] * self.gp[b]; },
                .IDIV => { const d = self.fetchU8(); const a = self.fetchU8(); const b = self.fetchU8(); self.gp[d] = @divTrunc(self.gp[a], self.gp[b]); },
                .INC => { const d = self.fetchU8(); self.gp[d] += 1; },
                .DEC => { const d = self.fetchU8(); self.gp[d] -= 1; },
                .JNZ => { const d = self.fetchU8(); const off = self.fetchI16(); if (self.gp[d] != 0) { self.pc = @intCast(@as(i32, @intCast(self.pc)) + off); } },
                .JZ => { const d = self.fetchU8(); const off = self.fetchI16(); if (self.gp[d] == 0) { self.pc = @intCast(@as(i32, @intCast(self.pc)) + off); } },
                .JMP => { const off = self.fetchI16(); self.pc = @intCast(@as(i32, @intCast(self.pc)) + off); },
                .PUSH => { const d = self.fetchU8(); self.stack[self.sp] = self.gp[d]; self.sp += 1; },
                .POP => { const d = self.fetchU8(); self.sp -= 1; self.gp[d] = self.stack[self.sp]; },
                .CMP => { const a = self.fetchU8(); const b = self.fetchU8(); self.gp[13] = if (self.gp[a] < self.gp[b]) -1 else if (self.gp[a] > self.gp[b]) 1 else 0; },
                else => { std.debug.print("Unknown opcode: 0x{x}\n", .{raw_op}); self.halted = true; },
            }
        }
        return self.cycles;
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("╔════════════════════════════════════════╗\n", .{});
    try stdout.print("║   FLUX Zig — High-Performance VM      ║\n", .{});
    try stdout.print("║   SuperInstance / Oracle1              ║\n", .{});
    try stdout.print("╚════════════════════════════════════════╝\n\n", .{});

    // Factorial(7)
    const fact = [_]u8{
        0x2B, 0x00, 0x07, 0x00,  // MOVI R0, 7
        0x2B, 0x01, 0x01, 0x00,  // MOVI R1, 1
        0x0A, 0x01, 0x01, 0x00,  // IMUL R1, R1, R0
        0x0F, 0x00,              // DEC R0
        0x06, 0x00, 0xF6, 0xFF,  // JNZ R0, -10
        0x80,                    // HALT
    };
    
    var vm = FluxVM{ .bytecode = &fact };
    const cycles = vm.execute();
    
    try stdout.print("Factorial(7): R1 = {} (cycles: {})\n", .{vm.gp[1], cycles});
    
    // Benchmark: 100K iterations
    const iters = 100_000;
    const start = std.time.nanoTimestamp();
    for (0..iters) |_| {
        var bvm = FluxVM{ .bytecode = &fact };
        _ = bvm.execute();
    }
    const end = std.time.nanoTimestamp();
    const elapsed_ns: f64 = @floatFromInt(end - start);
    
    try stdout.print("Benchmark (100K iters): {d:.0} ns/iter\n", .{elapsed_ns / @as(f64, @floatFromInt(iters))});
    try stdout.print("\n✓ FLUX Zig implementation working!\n", .{});
}

test "factorial(7) equals 5040" {
    const fact = [_]u8{
        0x2B, 0x00, 0x07, 0x00,
        0x2B, 0x01, 0x01, 0x00,
        0x0A, 0x01, 0x01, 0x00,
        0x0F, 0x00,
        0x06, 0x00, 0xF6, 0xFF,
        0x80,
    };
    var vm = FluxVM{ .bytecode = &fact };
    _ = vm.execute();
    try std.testing.expect(vm.gp[1] == 5040);
    try std.testing.expect(vm.halted);
}

test "arithmetic: 3 + 4 = 7" {
    const bc = [_]u8{ 0x2B, 0x00, 0x03, 0x00, 0x2B, 0x01, 0x04, 0x00, 0x08, 0x00, 0x00, 0x01, 0x80 };
    var vm = FluxVM{ .bytecode = &bc };
    _ = vm.execute();
    try std.testing.expect(vm.gp[0] == 7);
}

test "arithmetic: 10 * 5 = 50" {
    const bc = [_]u8{ 0x2B, 0x00, 0x0A, 0x00, 0x2B, 0x01, 0x05, 0x00, 0x0A, 0x00, 0x00, 0x01, 0x80 };
    var vm = FluxVM{ .bytecode = &bc };
    _ = vm.execute();
    try std.testing.expect(vm.gp[0] == 50);
}

test "INC and DEC" {
    const bc = [_]u8{ 0x2B, 0x00, 0x05, 0x00, 0x0E, 0x00, 0x0E, 0x00, 0x0F, 0x00, 0x80 };
    var vm = FluxVM{ .bytecode = &bc };
    _ = vm.execute();
    try std.testing.expect(vm.gp[0] == 6); // 5 + 1 + 1 - 1 = 6
}

test "fibonacci(12) = 144" {
    const bc = [_]u8{
        0x2B, 0x00, 0x00, 0x00,  // MOVI R0, 0
        0x2B, 0x01, 0x01, 0x00,  // MOVI R1, 1
        0x2B, 0x02, 0x0C, 0x00,  // MOVI R2, 12
        0x01, 0x03, 0x01,        // MOV R3, R1
        0x08, 0x01, 0x01, 0x00,  // IADD R1, R1, R0
        0x01, 0x00, 0x03,        // MOV R0, R3
        0x0F, 0x02,              // DEC R2
        0x06, 0x02, 0xF0, 0xFF,  // JNZ R2, -16
        0x80,                    // HALT
    };
    var vm = FluxVM{ .bytecode = &bc };
    _ = vm.execute();
    try std.testing.expect(vm.gp[0] == 144);
}

test "stack push and pop" {
    const bc = [_]u8{ 0x2B, 0x00, 0x2A, 0x00, 0x10, 0x00, 0x2B, 0x00, 0x00, 0x00, 0x11, 0x00, 0x80 };
    var vm = FluxVM{ .bytecode = &bc };
    _ = vm.execute();
    try std.testing.expect(vm.gp[0] == 42);
}

test "infinite loop protection" {
    const bc = [_]u8{ 0x2B, 0x00, 0x01, 0x00, 0x06, 0x00, 0xFC, 0xFF };
    var vm = FluxVM{ .bytecode = &bc };
    _ = vm.execute();
    try std.testing.expect(!vm.halted); // Should stop at max_cycles
    try std.testing.expect(vm.cycles == 10_000_000);
}
