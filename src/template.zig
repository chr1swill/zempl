const std = @import("std");
const print = std.debug.print;
const perr = std.log.err;

pub fn template_execute(arena: *std.mem.Allocator, template: []u8, data: anytype) ?[]const u8 {
    var i: usize = 0;
    var j: usize = 0;
    var c: u8 = undefined;
    var c_next: u8 = undefined;
    var last: usize = 0;
    var array: std.ArrayListUnmanaged(u8) = undefined;

    array = std.ArrayListUnmanaged(u8).initCapacity(arena.*, template.len) catch |err| {
        perr("could not allocate memory for array list: {}\n", .{err});
        return null;
    };

    i = 0;

    while (i < template.len - 1) {
        j = 0;

        c = template[i];
        c_next = template[i + 1];

        if (c == '{' and c_next == '{') {
            if (i < last) {
                perr("index={d} should not be greater than the last indexed value={d}\n", .{ i, last });
                return null;
            }

            array.appendSlice(arena.*, template[last..i]) catch |err| {
                perr("appending slice to array: {}\n", .{err});
                return null;
            };

            while (j < template.len - i and
                template[i + j] != '}' and
                template[i + j + 1] != '}')
            {
                j += 1;
            }

            if (i + j >= template.len) {
                perr("invalid template - found opening braces but no closing braces\n", .{});
                return null;
            }

            switch (@typeInfo(@TypeOf(data))) {
                .Type => {
                    @compileError(@TypeOf(data) ++ " currently has no handler\n");
                },
                .Bool => {
                    switch (data) {
                        true => {
                            array.appendSlice(arena.*, "true") catch |err| {
                                perr("failed to append \"true\" for boolean condition true: {}\n", .{err});
                                return null;
                            };
                        },
                        false => {
                            array.appendSlice(arena.*, "false") catch |err| {
                                perr("failed to append \"false\" for boolean condition false: {}\n", .{err});
                                return null;
                            };
                        },
                    }
                },
                .Int, .ComptimeInt => {
                    const items = std.fmt.parseInt(@TypeOf(data), data, 0) catch |err| {
                        perr("failed to parse data for its .Int value: {}\n", .{err});
                        return null;
                    };

                    array.appendSlice(arena.*, items) catch |err| {
                        perr("failed to append \"false\" for boolean condition false: {}\n", .{err});
                        return null;
                    };
                },
                .Float, .ComptimeFloat => {
                    const items = std.fmt.parseFloat(@TypeOf(data), data, 0) catch |err| {
                        perr("failed to parse data for its .Int value: {}\n", .{err});
                        return null;
                    };

                    array.appendSlice(arena.*, items) catch |err| {
                        perr("failed to append \"false\" for boolean condition false: {}\n", .{err});
                        return null;
                    };
                },
                .Struct => { // could capture |info| aswell
                    print("@typeInfo(.Struct)\n", .{});
                    const slot_name = std.mem.trim(u8, template[i .. i + j + 1], "{ }");
                    last = i + j + 3;

                    inline for (std.meta.fields(@TypeOf(data))) |field| {
                        if (std.mem.eql(u8, field.name, slot_name)) {
                            array.appendSlice(arena.*, @field(data, field.name)) catch |err| {
                                perr("failed to append .Struct={any} field={s} value={any}: {}\n", .{ @TypeOf(data), field.name, @field(data, field.name), err });
                                return null;
                            };
                            break;
                        } else {}
                    }
                },
                .Void, .NoReturn, .Pointer, .Array, .Undefined, .Null, .Optional, .ErrorUnion, .ErrorSet, .Enum, .Union, .Fn, .Opaque, .Frame, .AnyFrame, .Vector, .EnumLiteral => {
                    @compileLog("There is no handler set up for data type " ++ @TypeOf(data) ++ ", was its insertion intentionally?\n");
                },
            }
        }
        i += 1;
    }

    if (last > template.len) {
        perr("invalid stored last - index exceeded template.len={d}, last={d}\n", .{ template.len, last });
        return null;
    }

    array.appendSlice(arena.*, template[last..template.len]) catch |err| {
        perr("failed to append slice: {}\n", .{err});
        return null;
    };
    return array.items[0..array.items.len];
}

test "template accuracy with a single field struct" {
    var arena: std.heap.ArenaAllocator = undefined;
    var ally: std.mem.Allocator = undefined;

    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    ally = arena.allocator();

    const data = .{ .title = "easy" };
    const template: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>{{ title }}</title>
        \\</head>
        \\<body>
        \\</body>
        \\</html>
    ;
    const expected_result: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>easy</title>
        \\</head>
        \\<body>
        \\</body>
        \\</html>
    ;
    const result = template_execute(&ally, @constCast(template), data) orelse "";

    print("result vs what was expected\n\nexpected_result=\n{s}\n\nresult=\n{s}\n\n", .{ expected_result, result });
    try std.testing.expect(std.mem.eql(u8, expected_result, result));
}

test "template accuracy with a single field struct many slots" {
    var arena: std.heap.ArenaAllocator = undefined;
    var ally: std.mem.Allocator = undefined;

    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    ally = arena.allocator();

    // pub fn template_execute(comptime T: type, arena: *std.mem.Allocator, path: []const u8, data: T) ?[]const u8 {
    const data = .{ .title = "easy" };
    const template: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>{{ title }}</title>
        \\</head>
        \\<body>
        \\<h1>{{ title }}</h1>
        \\<h1>{{ title }}</h1>
        \\<h1>{{ title }}</h1>
        \\<h1>{{ title }}</h1>
        \\</body>
        \\</html>
    ;
    const expected_result: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>easy</title>
        \\</head>
        \\<body>
        \\<h1>easy</h1>
        \\<h1>easy</h1>
        \\<h1>easy</h1>
        \\<h1>easy</h1>
        \\</body>
        \\</html>
    ;
    const result = template_execute(&ally, @constCast(template), data) orelse "";

    print("result vs what was expected\n\nexpected_result=\n{s}\n\nresult=\n{s}\n\n", .{ expected_result, result });
    try std.testing.expect(std.mem.eql(u8, expected_result, result));
}

test "template_execute type struct with two fields" {
    var arena: std.heap.ArenaAllocator = undefined;
    var ally: std.mem.Allocator = undefined;

    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    ally = arena.allocator();

    // pub fn template_execute(comptime T: type, arena: *std.mem.Allocator, path: []const u8, data: T) ?[]const u8 {
    const data = .{ .title = "easy", .header = "News!" };
    const template: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>{{ title }}</title>
        \\</head>
        \\<body>
        \\<h1>{{ header }}</h1>
        \\</body>
        \\</html>
    ;
    const expected_result: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>easy</title>
        \\</head>
        \\<body>
        \\<h1>News!</h1>
        \\</body>
        \\</html>
    ;
    const result = template_execute(&ally, @constCast(template), data) orelse "";

    print("result vs what was expected\n\nexpected_result=\n{s}\n\nresult=\n{s}\n\n", .{ expected_result, result });
    try std.testing.expect(std.mem.eql(u8, expected_result, result));
}

test "template_execute type struct with two fields multiple" {
    var arena: std.heap.ArenaAllocator = undefined;
    var ally: std.mem.Allocator = undefined;

    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    ally = arena.allocator();

    // pub fn template_execute(comptime T: type, arena: *std.mem.Allocator, path: []const u8, data: T) ?[]const u8 {
    const data = .{ .title = "easy", .header = "News!" };
    const template: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>{{ title }}</title>
        \\</head>
        \\<body>
        \\<h1>{{ header }}</h1>
        \\<h1>{{ header }}</h1>
        \\</body>
        \\</html>
    ;
    const expected_result: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>easy</title>
        \\</head>
        \\<body>
        \\<h1>News!</h1>
        \\<h1>News!</h1>
        \\</body>
        \\</html>
    ;
    const result = template_execute(&ally, @constCast(template), data) orelse "";

    print("result vs what was expected\n\nexpected_result=\n{s}\n\nresult=\n{s}\n\n", .{ expected_result, result });
    try std.testing.expect(std.mem.eql(u8, expected_result, result));
}

test "template_execute type struct with two fields double single" {
    var arena: std.heap.ArenaAllocator = undefined;
    var ally: std.mem.Allocator = undefined;

    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    ally = arena.allocator();

    // pub fn template_execute(comptime T: type, arena: *std.mem.Allocator, path: []const u8, data: T) ?[]const u8 {
    const data = .{ .title = "easy", .header = "News!" };
    const template: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>{{ title }}</title>
        \\<title>{{ title }}</title>
        \\</head>
        \\<body>
        \\<h1>{{ header }}</h1>
        \\</body>
        \\</html>
    ;
    const expected_result: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>easy</title>
        \\<title>easy</title>
        \\</head>
        \\<body>
        \\<h1>News!</h1>
        \\</body>
        \\</html>
    ;
    const result = template_execute(&ally, @constCast(template), data) orelse "";

    print("result vs what was expected\n\nexpected_result=\n{s}\n\nresult=\n{s}\n\n", .{ expected_result, result });
    try std.testing.expect(std.mem.eql(u8, expected_result, result));
}

test "template_execute type struct with three fields double single" {
    var arena: std.heap.ArenaAllocator = undefined;
    var ally: std.mem.Allocator = undefined;

    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    ally = arena.allocator();

    // pub fn template_execute(comptime T: type, arena: *std.mem.Allocator, path: []const u8, data: T) ?[]const u8 {
    const data = .{ .title = "easy", .header = "News!", .subheader = "This is the smaller header" };
    const template: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>{{ title }}</title>
        \\<title>{{ title }}</title>
        \\</head>
        \\<body>
        \\<h1>{{ header }}</h1>
        \\<h1>{{ header }}</h1>
        \\<h2>{{ subheader }}</h2>
        \\<h2>{{ subheader }}</h2>
        \\</body>
        \\</html>
    ;
    const expected_result: []const u8 =
        \\<!doctype html>
        \\<html>
        \\<head>
        \\<title>easy</title>
        \\<title>easy</title>
        \\</head>
        \\<body>
        \\<h1>News!</h1>
        \\<h1>News!</h1>
        \\<h2>This is the smaller header</h2>
        \\<h2>This is the smaller header</h2>
        \\</body>
        \\</html>
    ;
    const result = template_execute(&ally, @constCast(template), data) orelse "";

    print("result vs what was expected\n\nexpected_result=\n{s}\n\nresult=\n{s}\n\n", .{ expected_result, result });
    try std.testing.expect(std.mem.eql(u8, expected_result, result));
}

test "your mom" {
    const i = "helllo";
    print("@typeInfo(i)={}\n", .{@typeInfo(@TypeOf(i))});
}
