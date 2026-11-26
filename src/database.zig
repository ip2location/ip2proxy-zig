//! A reader for the IP2Proxy BIN database formats (PX1 through PX12).
//!
//! `Database.open` memory-maps the file, so a multi-gigabyte database costs
//! address space rather than RAM and lookups touch only the pages they need.
//!
//! Lookups allocate nothing. A `Record`'s strings point into the database, so
//! keep the database open while you use them.

const std = @import("std");
const Io = std.Io;
const fields = @import("fields.zig");
const record = @import("record.zig");

pub const Record = record.Record;
pub const ProxyStatus = record.ProxyStatus;
pub const Field = record.Field;

pub const Error = error{
    /// The bytes do not look like an IP2Proxy BIN file.
    InvalidDatabase,
    /// The address is not in the database.
    AddressNotFound,
    /// The string is not a valid IPv4 or IPv6 address.
    InvalidAddress,
    /// The query is IPv6 but the database holds no IPv6 ranges.
    Ipv6NotInDatabase,
};

pub const Metadata = struct {
    /// Package type, 1 through 12 (PX1, PX2, PX12, ...).
    package: u8,
    /// 4-byte columns per record, including the start address.
    column_count: u8,
    year: u16,
    month: u8,
    day: u8,
    product_code: u8,
    license_code: u8,
    database_size: u8,
    ipv4_count: u32,
    ipv6_count: u32,
};

const Header = struct {
    meta: Metadata,
    ipv4_base: u32,
    ipv6_base: u32,
    ipv4_index: u32,
    ipv6_index: u32,
};

pub const Database = struct {
    bytes: []const u8,
    header: Header,
    io: Io,
    file: Io.File,
    map: Io.File.MemoryMap,

    /// Memory-map `path`. The mapping is read-only; the file is closed by
    /// `deinit`.
    pub fn open(io: Io, path: []const u8) !Database {
        const file = try Io.Dir.cwd().openFile(io, path, .{});
        errdefer file.close(io);

        const stat = try file.stat(io);
        if (stat.kind != .file or stat.size < 64) return Error.InvalidDatabase;

        var map = try Io.File.MemoryMap.create(io, file, .{
            .len = @intCast(stat.size),
            .protection = .{ .read = true },
        });
        errdefer map.destroy(io);

        const bytes: []const u8 = map.memory;
        return .{
            .bytes = bytes,
            .header = try parseHeader(bytes),
            .io = io,
            .file = file,
            .map = map,
        };
    }

    pub fn deinit(self: *Database) void {
        self.map.destroy(self.io);
        self.file.close(self.io);
    }

    pub fn metadata(self: *const Database) Metadata {
        return self.header.meta;
    }

    pub fn supportsIpv4(self: *const Database) bool {
        return self.header.meta.ipv4_count != 0;
    }

    pub fn supportsIpv6(self: *const Database) bool {
        return self.header.meta.ipv6_count != 0;
    }

    /// Look up one address, in IPv4 or IPv6 notation.
    pub fn lookup(self: *const Database, text: []const u8) !Record {
        const parsed = try parseAddress(text);
        return self.lookupNumber(parsed.version, parsed.number);
    }

    fn lookupNumber(self: *const Database, version: u3, number: u128) !Record {
        const row = try self.find(version, number);
        return self.readRecord(version, row);
    }

    fn find(self: *const Database, version: u3, number: u128) !u32 {
        const meta = self.header.meta;
        const count: u32 = if (version == 4) meta.ipv4_count else meta.ipv6_count;
        if (count == 0) {
            return if (version == 6) Error.Ipv6NotInDatabase else Error.AddressNotFound;
        }

        const step: u64 = if (version == 4)
            @as(u64, meta.column_count) * 4
        else
            @as(u64, meta.column_count) * 4 + 12;

        var low: u32 = 0;
        var high: u32 = count - 1;

        const index_base = if (version == 4) self.header.ipv4_index else self.header.ipv6_index;
        if (index_base > 0) {
            const slot: u64 = if (version == 4)
                @intCast(number >> 16)
            else
                @intCast(number >> 112);
            const at = @as(u64, index_base) + slot * 8 - 1;
            low = try self.readU32(at);
            const indexed_high = try self.readU32(at + 4);
            high = @min(indexed_high, count - 1);
        }

        while (low <= high) {
            const mid = low + (high - low) / 2;
            const row = self.rowStart(version, mid);
            const start = try self.readBoundary(version, row);
            const end = try self.readBoundary(version, row + step);

            if (number < start) {
                if (mid == 0) break;
                high = mid - 1;
            } else if (number >= end) {
                if (mid == count - 1) break;
                low = mid + 1;
            } else {
                return mid;
            }
        }
        return Error.AddressNotFound;
    }

    fn rowStart(self: *const Database, version: u3, index: u32) u64 {
        const base: u64 = if (version == 4) self.header.ipv4_base else self.header.ipv6_base;
        const step: u64 = if (version == 4)
            @as(u64, self.header.meta.column_count) * 4
        else
            @as(u64, self.header.meta.column_count) * 4 + 12;
        return base + @as(u64, index) * step - 1;
    }

    fn readBoundary(self: *const Database, version: u3, at: u64) !u128 {
        return if (version == 4)
            try self.readU32(at)
        else
            try self.readU128(at);
    }

    fn readRecord(self: *const Database, version: u3, row_index: u32) !Record {
        const row = self.rowStart(version, row_index);
        // IPv6 records start with a 16-byte address, IPv4 with a 4-byte one.
        const shift: u64 = if (version == 4) 0 else 12;
        const db_type = self.header.meta.package;
        var rec: Record = .{};

        inline for (fields.positions, 0..) |slots, i| {
            const slot = slots[db_type - 1];
            if (slot != 0) {
                const at = row + shift + 4 * (slot - 1);
                const f: Field = @enumFromInt(i);
                if (f == .country_name) {
                    // The country block is [len code][code][len name][name].
                    rec.country_name = try self.readStringAt((try self.readU32(at)) + 3);
                } else {
                    @field(rec, @tagName(f)) = try self.readStringAt(try self.readU32(at));
                }
            }
        }

        rec.is_proxy = proxyStatus(db_type, rec);
        return rec;
    }

    fn proxyStatus(db_type: u8, rec: Record) ProxyStatus {
        // PX1 carries country only; a dash means the range is not a proxy.
        if (db_type == 1) {
            const code = rec.country_code orelse return .not_proxy;
            return if (std.mem.eql(u8, code, "-")) .not_proxy else .proxy;
        }

        const kind = rec.proxy_type orelse return .not_proxy;
        if (std.mem.eql(u8, kind, "-")) return .not_proxy;
        if (std.mem.eql(u8, kind, "DCH") or
            std.mem.eql(u8, kind, "SES") or
            std.mem.eql(u8, kind, "AIC")) return .data_center;
        return .proxy;
    }

    fn readStringAt(self: *const Database, pointer: u32) !?[]const u8 {
        if (pointer == 0) return null;
        const at: u64 = pointer;
        if (at >= self.bytes.len) return Error.InvalidDatabase;
        const len = self.bytes[at];
        if (len == 0) return null;
        const start = at + 1;
        const end = start + len;
        if (end > self.bytes.len) return Error.InvalidDatabase;
        return self.bytes[@intCast(start)..@intCast(end)];
    }

    fn readU32(self: *const Database, at: u64) !u32 {
        if (at + 4 > self.bytes.len) return Error.InvalidDatabase;
        const i: usize = @intCast(at);
        return std.mem.readInt(u32, self.bytes[i..][0..4], .little);
    }

    fn readU128(self: *const Database, at: u64) !u128 {
        if (at + 16 > self.bytes.len) return Error.InvalidDatabase;
        const i: usize = @intCast(at);
        return std.mem.readInt(u128, self.bytes[i..][0..16], .little);
    }
};

const Parsed = struct { version: u3, number: u128 };

fn parseHeader(bytes: []const u8) !Header {
    const package = bytes[0];
    if (package < 1 or package > 12) return Error.InvalidDatabase;

    const column_count = bytes[1];
    if (column_count == 0 or column_count > 40) return Error.InvalidDatabase;

    const year: u16 = @as(u16, 2000) + bytes[2];
    const product_code = bytes[29];
    // Product code 1 marks an IP2Location file, which has a different layout.
    if (product_code == 1) return Error.InvalidDatabase;
    // IP2Proxy files from 2021 onwards carry product code 2. Older ones have 0.
    if (product_code != 2 and year >= 2021) return Error.InvalidDatabase;

    const h = Header{
        .meta = .{
            .package = package,
            .column_count = column_count,
            .year = year,
            .month = bytes[3],
            .day = bytes[4],
            .product_code = product_code,
            .license_code = bytes[30],
            .database_size = bytes[31],
            .ipv4_count = std.mem.readInt(u32, bytes[5..9], .little),
            .ipv6_count = std.mem.readInt(u32, bytes[13..17], .little),
        },
        .ipv4_base = std.mem.readInt(u32, bytes[9..13], .little),
        .ipv6_base = std.mem.readInt(u32, bytes[17..21], .little),
        .ipv4_index = std.mem.readInt(u32, bytes[21..25], .little),
        .ipv6_index = std.mem.readInt(u32, bytes[25..29], .little),
    };

    // Reject a header whose offsets point outside the file.
    const size: u64 = bytes.len;
    if (h.meta.ipv4_count != 0) {
        const end = @as(u64, h.ipv4_base) + @as(u64, h.meta.ipv4_count) * column_count * 4 + 4;
        if (h.ipv4_base == 0 or end > size) return Error.InvalidDatabase;
    }
    if (h.meta.ipv6_count != 0) {
        const end = @as(u64, h.ipv6_base) + @as(u64, h.meta.ipv6_count) * (column_count * 4 + 12) + 16;
        if (h.ipv6_base == 0 or end > size) return Error.InvalidDatabase;
    }
    return h;
}

fn parseAddress(text: []const u8) !Parsed {
    const address = Io.net.IpAddress.parse(text, 0) catch return Error.InvalidAddress;
    return addressToNumber(address);
}

fn addressToNumber(address: Io.net.IpAddress) !Parsed {
    switch (address) {
        .ip4 => |a| return .{ .version = 4, .number = clampIpv4(std.mem.readInt(u32, &a.bytes, .big)) },
        .ip6 => |a| {
            const number = std.mem.readInt(u128, &a.bytes, .big);

            // 6to4: 2002:AABB:CCDD::/48 carries the IPv4 address in bits 80-111.
            if (number >> 112 == 0x2002) {
                return .{ .version = 4, .number = clampIpv4(@truncate(number >> 80)) };
            }
            // Teredo: 2001:0000::/32 carries the IPv4 address inverted.
            if (number >> 96 == 0x20010000) {
                const last: u32 = @truncate(number);
                if (last != 0) return .{ .version = 4, .number = clampIpv4(~last) };
            }
            // IPv4-mapped: ::ffff:a.b.c.d.
            if (number >= 0x0000ffff00000000 and number <= 0x0000ffffffffffff) {
                return .{ .version = 4, .number = clampIpv4(@truncate(number)) };
            }
            return .{ .version = 6, .number = if (number == std.math.maxInt(u128)) number - 1 else number };
        },
    }
}

fn clampIpv4(number: u32) u32 {
    return if (number == std.math.maxInt(u32)) number - 1 else number;
}

test "rejects an IP2Location file" {
    var header = [_]u8{0} ** 64;
    header[0] = 1;
    header[1] = 2;
    header[2] = 20;
    header[29] = 1;
    try std.testing.expectError(Error.InvalidDatabase, parseHeader(&header));
}

test "address conversion" {
    try std.testing.expectEqual(Parsed{ .version = 4, .number = 0x08080808 }, try parseAddress("8.8.8.8"));
    try std.testing.expectEqual(Parsed{ .version = 4, .number = 0x08080808 }, try parseAddress("::ffff:8.8.8.8"));
    try std.testing.expectEqual(Parsed{ .version = 4, .number = 0x08080808 }, try parseAddress("2002:0808:0808::1"));
    try std.testing.expectEqual(Parsed{ .version = 6, .number = 0x20014860486000000000000000008888 }, try parseAddress("2001:4860:4860::8888"));
    try std.testing.expectError(Error.InvalidAddress, parseAddress("not an ip"));
}
