# IP2Proxy Zig Library

IP2Proxy zig library to allow user to query an IP address if it was being used as VPN servers, open proxies, web proxies, Tor exit nodes, search engine robots, data center ranges, residential proxies, consumer privacy networks, and enterprise private networks. It looks up the proxy IP address from an **IP2Proxy BIN Data** file. This data file can be downloaded at:

- Free IP2Proxy BIN Data: [https://lite.ip2location.com](https://lite.ip2location.com)
- Commercial IP2Proxy BIN Data: [https://www.ip2location.com/database/ip2proxy](https://www.ip2location.com/database/ip2proxy)

## Installation

```sh
zig fetch --save git+https://github.com/i2location/ip2proxy-zig
```

Then in `build.zig`:

```zig
const ip2proxy = b.dependency("ip2proxy", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("ip2proxy", ip2proxy.module("ip2proxy"));
```

## Usage

```zig
const std = @import("std");
const ip2proxy = @import("ip2proxy");

pub fn main(init: std.process.Init) !void {
    var db = try ip2proxy.Database.open(init.io, "PX12.BIN");
    defer db.deinit();

    const record = try db.lookup("146.70.116.130");
    std.debug.print("{s} {s} {s} {s}\n", .{
        record.proxy_type.?,
        record.country_code.?,
        record.city.?,
        record.provider.?,
    });
}
```

`zig build example` builds the same program as `zig-out/bin/lookup`, which takes a database path and an address:

```sh
./zig-out/bin/lookup PX12.BIN 146.70.116.130
```

### The proxy verdict

`record.is_proxy` is a `ProxyStatus`:

- `.not_proxy` (0): the range is not a proxy.
- `.proxy` (1): VPN, Tor, public, web, residential, consumer privacy or enterprise private network.
- `.data_center` (2): data center, search engine or AI crawler (`DCH`, `SES`, `AIC`).

A dash stored as the proxy type means not a proxy.

## Proxy Type

| Proxy Type | Description |
| --- | --- |
| VPN | Anonymizing VPN services. |
| TOR | Tor Exit Nodes. |
| PUB | Public Proxies. |
| WEB | Web Proxies. |
| DCH | Hosting Providers/Data Center. |
| SES | Search Engine Robots. |
| RES | Residential Proxies [PX10+] |
| CPN | Consumer Privacy Networks. [PX11+] |
| EPN | Enterprise Private Networks. [PX11+] |
| AIC | AI Crawler. [PX12] |

## Usage Type

| Usage Type | Description |
| --- | --- |
| COM | Commercial |
| ORG | Organization |
| GOV | Government |
| MIL | Military |
| EDU | University/College/School |
| LIB | Library |
| CDN | Content Delivery Network |
| ISP | Fixed Line ISP |
| MOB | Mobile ISP |
| DCH | Data Center/Web Hosting/Transit |
| SES | Search Engine Spider |
| AIC | AI Crawler |
| RSV | Reserved |

## Threat Type

| Threat Type | Description |
| --- | --- |
| SPAM | Email and forum spammers |
| SCANNER | Security Scanner or Attack |
| BOTNET | Spyware or Malware |
| BOGON | Unassigned or illegitimate IP addresses announced via BGP |

## API

| Member | Description |
| --- | --- |
| `Database.open(io, path)` | Memory-maps a BIN file read-only. `deinit` closes it. |
| `db.deinit()` | Releases the mapping and closes the file. |
| `db.lookup(text)` | Looks up one address in IPv4 or IPv6 notation and returns a `Record`. Fails with the errors listed below. |
| `db.metadata()` | Returns the package type, column count, build date and row counts. |
| `db.supportsIpv4()` | Whether the file carries IPv4 ranges. |
| `db.supportsIpv6()` | Whether the file carries IPv6 ranges. |
| `record.get(field)` | Returns one field as `?[]const u8`, for callers that choose fields at runtime. |

### Record fields

| Field | Type | Description |
| --- | --- | --- |
| `is_proxy` | `ProxyStatus` | Computed verdict: `.not_proxy`, `.proxy` or `.data_center`. |
| `proxy_type` | `?[]const u8` | Proxy type code such as `VPN`, `TOR`, `PUB`, `WEB`, `DCH`, `SES`, `RES`, `CPN`, `EPN` or `AIC`. |
| `country_code` | `?[]const u8` | ISO 3166 two-character country code. |
| `country_name` | `?[]const u8` | Country name. |
| `region` | `?[]const u8` | Region or state name. |
| `city` | `?[]const u8` | City name. |
| `isp` | `?[]const u8` | Internet service provider or company name. |
| `domain` | `?[]const u8` | Domain associated with the address range. |
| `usage_type` | `?[]const u8` | Usage classification of the ISP or company. |
| `asn` | `?[]const u8` | Autonomous system number. |
| `as_name` | `?[]const u8` | Autonomous system name. |
| `last_seen` | `?[]const u8` | Days since the proxy was last seen. |
| `threat` | `?[]const u8` | Security threat reported for the address. |
| `provider` | `?[]const u8` | VPN provider name, when known. |
| `fraud_score` | `?[]const u8` | Risk score from 0 to 99. |

## Errors

`db.lookup` fails with:

- `error.InvalidAddress` — the text is not an IPv4 or IPv6 address.
- `error.AddressNotFound` — no range in the database contains the address.
- `error.Ipv6NotInDatabase` — an IPv6 address was given to an IPv4-only database.
- `error.InvalidDatabase` — the header or a record points outside the file, or the file is not an IP2Proxy database.

`Database.open` also returns the usual file and memory-map errors.

## Tests

```sh
zig build test
```

The suite runs against the PX10 sample BIN in `test/testdata` and has been cross-checked against the official IP2Proxy PHP SDK on PX2 and PX12, over IPv4 and IPv6, including provider and fraud score.

## Support

Email: support@ip2location.com.

URL: [https://www.ip2location.com](https://www.ip2location.com)

## License

MIT, see [LICENSE](LICENSE).
