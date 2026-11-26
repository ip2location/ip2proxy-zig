const std = @import("std");
const ip2proxy = @import("ip2proxy");

const px10_path = "test/testdata/PX10.SAMPLE.BIN";

test "PX10 IPv4 record" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    var db = try ip2proxy.Database.open(threaded.io(), px10_path);
    defer db.deinit();

    const r = try db.lookup("1.0.0.8");
    try std.testing.expectEqual(ip2proxy.ProxyStatus.data_center, r.is_proxy);
    try std.testing.expectEqualStrings("DCH", r.proxy_type.?);
    try std.testing.expectEqualStrings("US", r.country_code.?);
    try std.testing.expectEqualStrings("United States of America", r.country_name.?);
    try std.testing.expectEqualStrings("California", r.region.?);
    try std.testing.expectEqualStrings("Los Angeles", r.city.?);
    try std.testing.expectEqualStrings("APNIC and CloudFlare DNS Resolver Project", r.isp.?);
    try std.testing.expectEqualStrings("cloudflare.com", r.domain.?);
    try std.testing.expectEqualStrings("CDN", r.usage_type.?);
    try std.testing.expectEqualStrings("13335", r.asn.?);
    try std.testing.expectEqualStrings("CLOUDFLARENET", r.as_name.?);
    try std.testing.expectEqualStrings("22", r.last_seen.?);
    try std.testing.expectEqualStrings("-", r.threat.?);
}

test "PX10 IPv6 record" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    var db = try ip2proxy.Database.open(threaded.io(), px10_path);
    defer db.deinit();

    const r = try db.lookup("2c0f:ffa0::4");
    try std.testing.expectEqualStrings("UG", r.country_code.?);
    try std.testing.expectEqualStrings("Uganda", r.country_name.?);
}

test "metadata and runtime field access" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    var db = try ip2proxy.Database.open(threaded.io(), px10_path);
    defer db.deinit();

    const meta = db.metadata();
    try std.testing.expectEqual(@as(u8, 10), meta.package);
    try std.testing.expectEqual(@as(u16, 2020), meta.year);
    try std.testing.expectEqual(@as(u8, 10), meta.month);
    try std.testing.expectEqual(@as(u8, 23), meta.day);
    try std.testing.expect(db.supportsIpv4());
    try std.testing.expect(db.supportsIpv6());

    const r = try db.lookup("1.0.0.8");
    try std.testing.expectEqualStrings("DCH", r.get(.proxy_type).?);
    try std.testing.expectEqualStrings("Los Angeles", r.get(.city).?);
    try std.testing.expect(r.get(.provider) == null);
    try std.testing.expect(r.get(.fraud_score) == null);
}

test "invalid input" {
    var threaded: std.Io.Threaded = .init(std.testing.allocator, .{});
    defer threaded.deinit();
    var db = try ip2proxy.Database.open(threaded.io(), px10_path);
    defer db.deinit();

    try std.testing.expectError(ip2proxy.Error.InvalidAddress, db.lookup("not an ip"));
}
