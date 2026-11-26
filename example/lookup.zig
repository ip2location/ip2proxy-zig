//!     zig build example
//!     ./zig-out/bin/lookup PX12.BIN 4.0.0.47

const std = @import("std");
const ip2proxy = @import("ip2proxy");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 3) {
        std.debug.print("usage: {s} DATABASE.bin IP\n", .{args[0]});
        return error.MissingArguments;
    }

    var db = try ip2proxy.Database.open(init.io, args[1]);
    defer db.deinit();

    const record = try db.lookup(args[2]);
    const verdict = switch (record.is_proxy) {
        .not_proxy => "not a proxy",
        .proxy => "proxy",
        .data_center => "data center, search engine or crawler",
    };
    std.debug.print("is_proxy  {s}\n", .{verdict});
    std.debug.print("type      {s}\n", .{record.proxy_type orelse "-"});
    std.debug.print("country   {s}\n", .{record.country_code orelse "-"});
    std.debug.print("name      {s}\n", .{record.country_name orelse "-"});
    std.debug.print("region    {s}\n", .{record.region orelse "-"});
    std.debug.print("city      {s}\n", .{record.city orelse "-"});
    std.debug.print("isp       {s}\n", .{record.isp orelse "-"});
    std.debug.print("asn       {s}\n", .{record.asn orelse "-"});
    std.debug.print("provider  {s}\n", .{record.provider orelse "-"});
    std.debug.print("threat    {s}\n", .{record.threat orelse "-"});
    std.debug.print("fraud     {s}\n", .{record.fraud_score orelse "-"});
}
