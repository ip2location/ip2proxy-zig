# Quickstart

## Dependencies

This library requires an IP2Proxy BIN database to function. You may download the BIN database at

- IP2Proxy LITE BIN Data (Free): <https://lite.ip2location.com>
- IP2Proxy Commercial BIN Data (Comprehensive): <https://www.ip2location.com/proxy-database>

:::{note}
A sample BIN file is provided in the `test/testdata` folder for testing. You are recommended to visit the above links to download the latest BIN database.
:::

This library requires Zig 0.16.0. It memory-maps the BIN file, so the database may be larger than available RAM.

## Installation

```sh
zig fetch --save git+https://github.com/<org>/ip2proxy-zig
```

Then add the module in `build.zig`:

```zig
const ip2proxy = b.dependency("ip2proxy", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("ip2proxy", ip2proxy.module("ip2proxy"));
```

## Sample Codes

### Detect proxy information from BIN database

You can query the proxy information from the IP2Proxy BIN database as below:

```zig
const std = @import("std");
const ip2proxy = @import("ip2proxy");

pub fn main(init: std.process.Init) !void {
    var db = try ip2proxy.Database.open(init.io, "PX12.BIN");
    defer db.deinit();

    const record = try db.lookup("4.0.0.47");
    std.debug.print("is_proxy={s} type={s} country={s} city={s}\n", .{
        @tagName(record.is_proxy),
        record.proxy_type orelse "-",
        record.country_code orelse "-",
        record.city orelse "-",
    });
}
```

`record.is_proxy` is `.not_proxy`, `.proxy` or `.data_center`. `Database.open` memory-maps the file read-only, and `db.deinit` releases the mapping. A `Record` borrows the database's memory, so keep the database open while you use it.
