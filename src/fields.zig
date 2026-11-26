//! Field layout of the IP2Proxy BIN formats, PX1 through PX12.
//! Taken from the official IP2Proxy SDK position table; do not hand-edit.

pub const Field = enum {
    proxy_type,
    country_code,
    country_name,
    region,
    city,
    isp,
    domain,
    usage_type,
    asn,
    as_name,
    last_seen,
    threat,
    provider,
    fraud_score,
};

pub const field_count = @typeInfo(Field).@"enum".fields.len;

/// A field's 4-byte slot inside a record (1-based; slot 1 is the start IP).
/// Indexed by [field][database type - 1]; 0 means the database omits it.
pub const positions: [field_count][12]u8 = .{
    .{ 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }, // proxy_type
    .{ 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3 }, // country_code
    .{ 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3 }, // country_name
    .{ 0, 0, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 }, // region
    .{ 0, 0, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 }, // city
    .{ 0, 0, 0, 6, 6, 6, 6, 6, 6, 6, 6, 6 }, // isp
    .{ 0, 0, 0, 0, 7, 7, 7, 7, 7, 7, 7, 7 }, // domain
    .{ 0, 0, 0, 0, 0, 8, 8, 8, 8, 8, 8, 8 }, // usage_type
    .{ 0, 0, 0, 0, 0, 0, 9, 9, 9, 9, 9, 9 }, // asn
    .{ 0, 0, 0, 0, 0, 0, 10, 10, 10, 10, 10, 10 }, // as_name
    .{ 0, 0, 0, 0, 0, 0, 0, 11, 11, 11, 11, 11 }, // last_seen
    .{ 0, 0, 0, 0, 0, 0, 0, 0, 12, 12, 12, 12 }, // threat
    .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 13 }, // provider
    .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 14 }, // fraud_score
};
