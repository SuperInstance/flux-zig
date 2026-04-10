const std = @import("std");
const FluxVM = @import("main.zig").FluxVM;

pub const VocabEntry = struct {
    pattern: []const u8,
    asm_template: []const u8,
    name: []const u8,
};

pub const Vocabulary = struct {
    entries: []const VocabEntry,
    allocator: std.mem.Allocator,

    fn match(self: *const Vocabulary, text: []const u8) ?*const VocabEntry {
        for (self.entries) |*entry| {
            if (self.matchesPattern(text, entry.pattern)) {
                return entry;
            }
        }
        return null;
    }

    fn matchesPattern(_: *const Vocabulary, text: []const u8, pattern: []const u8) bool {
        // Simple token-based matching
        var pattern_words = std.mem.tokenizeScalar(u8, pattern, ' ');
        var text_words = std.mem.tokenizeScalar(u8, text, ' ');

        while (true) {
            const pattern_word = pattern_words.next();
            const text_word = text_words.next();

            if (pattern_word == null and text_word == null) return true;
            if (pattern_word == null or text_word == null) return false;

            // Check if this is a placeholder (A, B, or N as standalone word)
            if (pattern_word.?.len == 1 and (pattern_word.?[0] == 'A' or pattern_word.?[0] == 'B' or pattern_word.?[0] == 'N')) {
                // Placeholder matches any word
                continue;
            }

            // Regular word comparison (case-insensitive)
            if (!std.ascii.eqlIgnoreCase(pattern_word.?, text_word.?)) {
                return false;
            }
        }
    }

    fn extractValue(text: []const u8, pattern: []const u8, placeholder: u8) ?i32 {
        var pattern_words = std.mem.tokenizeScalar(u8, pattern, ' ');
        var text_words = std.mem.tokenizeScalar(u8, text, ' ');
        var placeholder_idx: usize = 0;

        while (true) {
            const pattern_word = pattern_words.next();
            const text_word = text_words.next();

            if (pattern_word == null or text_word == null) break;

            // Check if this is the target placeholder
            if (pattern_word.?.len == 1 and pattern_word.?[0] == placeholder) {
                placeholder_idx += 1;
                // Extract value from corresponding text word
                return std.fmt.parseInt(i32, text_word.?, 10) catch null;
            }
        }
        return null;
    }

    fn substitute(self: *const Vocabulary, template: []const u8, text: []const u8, pattern: []const u8) ![]u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        var i: usize = 0;
        while (i < template.len) {
            if (i + 2 < template.len and template[i] == '{' and template[i + 1] == 'A' and template[i + 2] == '}') {
                const val = extractValue(text, pattern, 'A') orelse return error.InvalidPattern;
                try result.writer().print("{d}", .{val});
                i += 3;
            } else if (i + 2 < template.len and template[i] == '{' and template[i + 1] == 'B' and template[i + 2] == '}') {
                const val = extractValue(text, pattern, 'B') orelse return error.InvalidPattern;
                try result.writer().print("{d}", .{val});
                i += 3;
            } else if (i + 2 < template.len and template[i] == '{' and template[i + 1] == 'N' and template[i + 2] == '}') {
                const val = extractValue(text, pattern, 'N') orelse return error.InvalidPattern;
                try result.writer().print("{d}", .{val});
                i += 3;
            } else {
                try result.append(template[i]);
                i += 1;
            }
        }

        return result.toOwnedSlice();
    }

    fn assemble(self: *const Vocabulary, asm_code: []const u8) ![]const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        var lines = std.mem.splitScalar(u8, asm_code, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0 or trimmed[0] == ';') continue;

            var parts = std.mem.splitScalar(u8, trimmed, ' ');
            const op_name = parts.next() orelse continue;

            if (std.mem.eql(u8, op_name, "MOVI")) {
                const reg_str = parts.next() orelse return error.InvalidAsm;
                const val_str = parts.next() orelse return error.InvalidAsm;
                const reg = try std.fmt.parseInt(u8, reg_str[1..], 10);
                const val = try std.fmt.parseInt(i16, val_str, 10);
                try result.append(0x2B); // MOVI
                try result.append(reg);
                try result.append(@intCast(val & 0xFF));
                try result.append(@intCast((val >> 8) & 0xFF));
            } else if (std.mem.eql(u8, op_name, "MOV")) {
                const dst_str = parts.next() orelse return error.InvalidAsm;
                const src_str = parts.next() orelse return error.InvalidAsm;
                const dst = try std.fmt.parseInt(u8, dst_str[1..], 10);
                const src = try std.fmt.parseInt(u8, src_str[1..], 10);
                try result.append(0x01); // MOV
                try result.append(dst);
                try result.append(src);
            } else if (std.mem.eql(u8, op_name, "IMUL")) {
                const dst_str = parts.next() orelse return error.InvalidAsm;
                const a_str = parts.next() orelse return error.InvalidAsm;
                const b_str = parts.next() orelse return error.InvalidAsm;
                const dst = try std.fmt.parseInt(u8, dst_str[1..], 10);
                const a = try std.fmt.parseInt(u8, a_str[1..], 10);
                const b = try std.fmt.parseInt(u8, b_str[1..], 10);
                try result.append(0x0A); // IMUL
                try result.append(dst);
                try result.append(a);
                try result.append(b);
            } else if (std.mem.eql(u8, op_name, "IADD")) {
                const dst_str = parts.next() orelse return error.InvalidAsm;
                const a_str = parts.next() orelse return error.InvalidAsm;
                const b_str = parts.next() orelse return error.InvalidAsm;
                const dst = try std.fmt.parseInt(u8, dst_str[1..], 10);
                const a = try std.fmt.parseInt(u8, a_str[1..], 10);
                const b = try std.fmt.parseInt(u8, b_str[1..], 10);
                try result.append(0x08); // IADD
                try result.append(dst);
                try result.append(a);
                try result.append(b);
            } else if (std.mem.eql(u8, op_name, "DEC")) {
                const reg_str = parts.next() orelse return error.InvalidAsm;
                const reg = try std.fmt.parseInt(u8, reg_str[1..], 10);
                try result.append(0x0F); // DEC
                try result.append(reg);
            } else if (std.mem.eql(u8, op_name, "INC")) {
                const reg_str = parts.next() orelse return error.InvalidAsm;
                const reg = try std.fmt.parseInt(u8, reg_str[1..], 10);
                try result.append(0x0E); // INC
                try result.append(reg);
            } else if (std.mem.eql(u8, op_name, "JNZ")) {
                const reg_str = parts.next() orelse return error.InvalidAsm;
                const off_str = parts.next() orelse return error.InvalidAsm;
                const reg = try std.fmt.parseInt(u8, reg_str[1..], 10);
                const off = try std.fmt.parseInt(i16, off_str, 10);
                try result.append(0x06); // JNZ
                try result.append(reg);
                try result.append(@intCast(off & 0xFF));
                try result.append(@intCast((off >> 8) & 0xFF));
            } else if (std.mem.eql(u8, op_name, "JZ")) {
                const reg_str = parts.next() orelse return error.InvalidAsm;
                const off_str = parts.next() orelse return error.InvalidAsm;
                const reg = try std.fmt.parseInt(u8, reg_str[1..], 10);
                const off = try std.fmt.parseInt(i16, off_str, 10);
                try result.append(0x2E); // JZ
                try result.append(reg);
                try result.append(@intCast(off & 0xFF));
                try result.append(@intCast((off >> 8) & 0xFF));
            } else if (std.mem.eql(u8, op_name, "JMP")) {
                const off_str = parts.next() orelse return error.InvalidAsm;
                const off = try std.fmt.parseInt(i16, off_str, 10);
                try result.append(0x07); // JMP
                try result.append(@intCast(off & 0xFF));
                try result.append(@intCast((off >> 8) & 0xFF));
            } else if (std.mem.eql(u8, op_name, "CMP")) {
                const a_str = parts.next() orelse return error.InvalidAsm;
                const b_str = parts.next() orelse return error.InvalidAsm;
                const a = try std.fmt.parseInt(u8, a_str[1..], 10);
                const b = try std.fmt.parseInt(u8, b_str[1..], 10);
                try result.append(0x2D); // CMP
                try result.append(a);
                try result.append(b);
            } else if (std.mem.eql(u8, op_name, "HALT")) {
                try result.append(0x80); // HALT
            }
        }

        return result.toOwnedSlice();
    }

    pub fn interpret(self: *const Vocabulary, text: []const u8) !i32 {
        const entry = self.match(text) orelse return error.NoMatch;
        const substituted = try self.substitute(entry.asm_template, text, entry.pattern);
        defer self.allocator.free(substituted);

        const bytecode = try self.assemble(substituted);
        defer self.allocator.free(bytecode);

        var vm = FluxVM{ .bytecode = bytecode };
        _ = vm.execute();

        return vm.gp[0];
    }
};

pub fn createDefaultVocabulary(allocator: std.mem.Allocator) !Vocabulary {
    const entries = try allocator.alloc(VocabEntry, 5);

    entries[0] = VocabEntry{
        .pattern = "compute A + B",
        .asm_template =
        \\MOVI R0 {A}
        \\MOVI R1 {B}
        \\IADD R0 R0 R1
        \\HALT
        ,
        .name = "add",
    };

    entries[1] = VocabEntry{
        .pattern = "compute A * B",
        .asm_template =
        \\MOVI R0 {A}
        \\MOVI R1 {B}
        \\IMUL R0 R0 R1
        \\HALT
        ,
        .name = "multiply",
    };

    entries[2] = VocabEntry{
        .pattern = "factorial of N",
        .asm_template =
        \\MOVI R0 {N}
        \\MOVI R1 1
        \\IMUL R1 R1 R0
        \\DEC R0
        \\JNZ R0 -10
        \\MOV R0 R1
        \\HALT
        ,
        .name = "factorial",
    };

    entries[3] = VocabEntry{
        .pattern = "double N",
        .asm_template =
        \\MOVI R0 {N}
        \\MOVI R1 2
        \\IMUL R0 R0 R1
        \\HALT
        ,
        .name = "double",
    };

    entries[4] = VocabEntry{
        .pattern = "hello",
        .asm_template =
        \\MOVI R0 42
        \\HALT
        ,
        .name = "hello",
    };

    return Vocabulary{
        .entries = entries,
        .allocator = allocator,
    };
}

test "vocabulary: compute A + B" {
    const allocator = std.testing.allocator;
    var vocab = try createDefaultVocabulary(allocator);
    defer allocator.free(vocab.entries);

    const result = try vocab.interpret("compute 3 + 4");
    try std.testing.expect(result == 7);
}

test "vocabulary: compute A * B" {
    const allocator = std.testing.allocator;
    var vocab = try createDefaultVocabulary(allocator);
    defer allocator.free(vocab.entries);

    const result = try vocab.interpret("compute 5 * 6");
    try std.testing.expect(result == 30);
}

test "vocabulary: factorial of N" {
    const allocator = std.testing.allocator;
    var vocab = try createDefaultVocabulary(allocator);
    defer allocator.free(vocab.entries);

    const result = try vocab.interpret("factorial of 5");
    try std.testing.expect(result == 120);
}

test "vocabulary: double N" {
    const allocator = std.testing.allocator;
    var vocab = try createDefaultVocabulary(allocator);
    defer allocator.free(vocab.entries);

    const result = try vocab.interpret("double 21");
    try std.testing.expect(result == 42);
}

test "vocabulary: hello" {
    const allocator = std.testing.allocator;
    var vocab = try createDefaultVocabulary(allocator);
    defer allocator.free(vocab.entries);

    const result = try vocab.interpret("hello");
    try std.testing.expect(result == 42);
}

test "vocabulary: no match error" {
    const allocator = std.testing.allocator;
    var vocab = try createDefaultVocabulary(allocator);
    defer allocator.free(vocab.entries);

    const result = vocab.interpret("unknown command");
    try std.testing.expectError(error.NoMatch, result);
}

test "vocabulary: pattern matching case insensitive" {
    const allocator = std.testing.allocator;
    var vocab = try createDefaultVocabulary(allocator);
    defer allocator.free(vocab.entries);

    const result1 = try vocab.interpret("COMPUTE 3 + 4");
    try std.testing.expect(result1 == 7);

    const result2 = try vocab.interpret("Compute 10 * 2");
    try std.testing.expect(result2 == 20);
}

test "vocabulary: factorial of 7" {
    const allocator = std.testing.allocator;
    var vocab = try createDefaultVocabulary(allocator);
    defer allocator.free(vocab.entries);

    const result = try vocab.interpret("factorial of 7");
    try std.testing.expect(result == 5040);
}
