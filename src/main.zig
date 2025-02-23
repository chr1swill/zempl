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

pub fn main() !void {
    var server: std.net.Server = undefined;
    var arena: std.heap.ArenaAllocator = undefined;
    var ally: std.mem.Allocator = undefined;
    var client_buff: []u8 = undefined;
    var client: std.http.Server = undefined;

    const addr = try std.net.Address.parseIp("127.0.0.1", 8080);
    server = try std.net.Address.listen(addr, .{
        .reuse_address = true,
    });
    defer server.deinit();

    std.log.info("server listen on port 8080\n", .{});
    while (true) {
        arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const conn = try server.accept();
        defer {
            var ok: bool = undefined;

            ok = arena.reset(std.heap.ArenaAllocator.ResetMode.retain_capacity);
            if (!ok) {
                std.log.err("falied to reset the arena\n", .{});
            }
            arena.deinit();
            conn.stream.close();
        }

        ally = arena.allocator();

        client_buff = ally.alloc(u8, 2 << 15) catch |err| {
            std.log.err("failed to allocated memory: {}\n", .{err});
            return;
        };
        @memset(client_buff, 0);

        client = std.http.Server.init(conn, client_buff);

        while (client.state == .ready) {
            var request = client.receiveHead() catch |err| switch (err) {
                std.http.Server.ReceiveHeadError.HttpConnectionClosing => break,
                else => return err,
            };

            _ = try request.reader();
            request_logger(&request);

            handler_func(&ally, "/", &request, handle_homepage);

            request.respond("404 Not Found\n", .{
                .status = .not_found,
                .transfer_encoding = .chunked,
                .reason = "Not Found\n",
                .keep_alive = false,
            }) catch |err| {
                std.log.err("failed send back response: {}\n", .{err});
                return;
            };
        }
    }
}
