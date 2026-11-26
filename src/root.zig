//! Zig reader for the IP2Proxy BIN databases, PX1 through PX12.
//!
//! ```zig
//! var db = try ip2proxy.Database.open(io, "PX12.BIN");
//! defer db.deinit();
//!
//! const record = try db.lookup("4.0.0.47");
//! if (record.is_proxy != .not_proxy) {
//!     std.debug.print("{s} {s}\n", .{ record.proxy_type.?, record.country_code.? });
//! }
//! ```
//!
//! `Database.open` memory-maps the file, so a database larger than RAM is fine.
//! Lookups allocate nothing and a `Record` borrows the database's memory.

pub const Database = @import("database.zig").Database;
pub const Error = @import("database.zig").Error;
pub const Metadata = @import("database.zig").Metadata;

pub const Field = @import("record.zig").Field;
pub const ProxyStatus = @import("record.zig").ProxyStatus;
pub const Record = @import("record.zig").Record;

test {
    _ = @import("database.zig");
    _ = @import("record.zig");
}
