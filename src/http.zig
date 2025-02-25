const std = @import("std");
const tmpl = @import("template.zig");

pub fn request_logger(r: *std.http.Server.Request) void {
    std.log.info("{d} {s}", .{ r.head.method, r.head.target });
    return;
}

pub fn handler_func(ally: *std.mem.Allocator, path: []const u8, r: *std.http.Server.Request, handler: fn (ally: *std.mem.Allocator, r: *std.http.Server.Request) void) void {
    if (std.mem.eql(u8, r.head.target, path)) {
        handler(ally, r);
        return;
    }
}

const TmplHomeData = struct {
    title: []const u8,
    header: []const u8,
};

pub fn handle_homepage(ally: *std.mem.Allocator, r: *std.http.Server.Request) void {
    if (r.head.method != std.http.Method.GET) {
        std.log.err("Method not allowed: {}", .{r.head.method});

        r.respond("Method not allowed", .{
            .status = .method_not_allowed,
            .reason = "Method not allowed",
            .keep_alive = true,
            .transfer_encoding = .chunked,
        }) catch |err| {
            std.log.err("failed send back response: {}\n", .{err});
            return;
        };
    }

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

    const template_content = tmpl.template_execute(ally, @constCast(template), TmplHomeData{ .title = "this is the home page of the website", .header = "the main header" }) orelse "";

    const option = .{
        .status = .ok,
        .reason = "Ok",
        .transfer_encoding = .chunked,
        .keep_alive = true,
    };

    r.respond(template_content, option) catch |err| {
        std.log.err("failed send back response: {}\n", .{err});
        return;
    };
}
