# IP2Proxy Zig API

## Database

| Member | Description |
| --- | --- |
| `Database.open(io, path)` | Memory-maps a BIN file read-only. `deinit` closes it. |
| `db.deinit()` | Releases the mapping and closes the file. |
| `db.lookup(text)` | Looks up one address in IPv4 or IPv6 notation and returns a `Record`. Fails with the errors listed below. |
| `db.metadata()` | Returns the package type, column count, build date and row counts. |
| `db.supportsIpv4()` | Whether the file carries IPv4 ranges. |
| `db.supportsIpv6()` | Whether the file carries IPv6 ranges. |
| `record.get(field)` | Returns one field as `?[]const u8`, for callers that choose fields at runtime. |

## Proxy status

`record.is_proxy` is a `ProxyStatus`:

| Value | Number | Meaning |
| --- | --- | --- |
| `.not_proxy` | 0 | The range is not a proxy. |
| `.proxy` | 1 | VPN, Tor, public, web, residential, consumer privacy or enterprise private network. |
| `.data_center` | 2 | Data center, search engine or AI crawler (`DCH`, `SES`, `AIC`). |

## Record fields

| Field Name | Type | Description |
| --- | --- | --- |
| `is_proxy` | `ProxyStatus` | Computed verdict. |
| `proxy_type` | `?[]const u8` | Proxy type: `VPN`, `TOR`, `PUB`, `WEB`, `DCH`, `SES`, `RES`, `CPN`, `EPN` or `AIC`. |
| `country_code` | `?[]const u8` | Two-character country code based on ISO 3166. |
| `country_name` | `?[]const u8` | Country name based on ISO 3166. |
| `region` | `?[]const u8` | Region or state name. |
| `city` | `?[]const u8` | City name. |
| `isp` | `?[]const u8` | Internet Service Provider or company's name. |
| `domain` | `?[]const u8` | Internet domain name associated with IP address range. |
| `usage_type` | `?[]const u8` | Usage type classification of the ISP or company. |
| `asn` | `?[]const u8` | Autonomous system number (ASN). |
| `as_name` | `?[]const u8` | Autonomous system (AS) name. |
| `last_seen` | `?[]const u8` | Proxy last seen, in days. |
| `threat` | `?[]const u8` | Security threat reported for the address. |
| `provider` | `?[]const u8` | VPN provider name, when available. |
| `fraud_score` | `?[]const u8` | IP2Proxy fraud score from 0 to 99. |

A field is null when the database does not carry it or the record has no value for it. A dash stored in the file stays a dash.

## Errors

| Error | Meaning |
| --- | --- |
| `error.InvalidAddress` | The text is not an IPv4 or IPv6 address. |
| `error.AddressNotFound` | No range in the database contains the address. |
| `error.Ipv6NotInDatabase` | An IPv6 address was given to an IPv4-only database. |
| `error.InvalidDatabase` | The header or a record points outside the file, or the file is not an IP2Proxy database. |

`Database.open` also returns the usual file and memory-map errors.
