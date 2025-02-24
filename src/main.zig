const std = @import("std");
const tmpl = @import("template.zig");
const http = @import("http.zig");

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
            http.request_logger(&request);

            http.handler_func(&ally, "/", &request, http.handle_homepage);

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
