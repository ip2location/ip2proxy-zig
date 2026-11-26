//! The result of a lookup: the proxy verdict plus every field the database
//! carries, null when the database does not carry it or the record has no
//! value for it.

const fields = @import("fields.zig");

pub const Field = fields.Field;

/// The `is_proxy` verdict, with the same values as the official SDKs.
pub const ProxyStatus = enum(u2) {
    not_proxy = 0,
    proxy = 1,
    /// Data center, search engine or AI crawler: the address is not residential.
    data_center = 2,
};

/// Strings point into the database's memory, so a record is valid only while
/// its `Database` is open. No allocation, no `deinit`.
pub const Record = struct {
    is_proxy: ProxyStatus = .not_proxy,
    proxy_type: ?[]const u8 = null,
    country_code: ?[]const u8 = null,
    country_name: ?[]const u8 = null,
    region: ?[]const u8 = null,
    city: ?[]const u8 = null,
    isp: ?[]const u8 = null,
    domain: ?[]const u8 = null,
    usage_type: ?[]const u8 = null,
    asn: ?[]const u8 = null,
    as_name: ?[]const u8 = null,
    last_seen: ?[]const u8 = null,
    threat: ?[]const u8 = null,
    provider: ?[]const u8 = null,
    fraud_score: ?[]const u8 = null,

    pub fn get(self: Record, field: Field) ?[]const u8 {
        return switch (field) {
            inline else => |f| @field(self, @tagName(f)),
        };
    }
};
