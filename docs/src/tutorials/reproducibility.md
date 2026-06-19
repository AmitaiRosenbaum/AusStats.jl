# Testing And Reproducibility

AusStats.jl is designed so ordinary test runs do not depend on the
ABS website. Network access is explicit, cached, and optional.

## Offline Tests

The default test suite uses saved HTML fixtures, synthetic workbook fixtures,
cube fixtures, and API response fixtures.

```julia
using Pkg
Pkg.test("AusStats")
```

From a local checkout, you can also run:

```julia
include("test/runtests.jl")
```

The fixture notes are stored in `test/fixtures/README.md`.

## Online Tests

Online tests are skipped unless explicitly enabled:

```julia
ENV["AusStats_ONLINE_TESTS"] = "true"
include("test/runtests.jl")
```

The online checks exercise latest-release discovery, historical release
resolution, workbook downloads, and API access. Assertions are deliberately
conservative because latest ABS data can change.

## Reproducible Reads

For reproducible analysis, prefer explicit catalogue numbers, tables, release
dates, and cache controls:

```julia
using Dates

df = read_abs(
    "6345.0";
    release=Date(2019, 9, 1),
    tables=2,
    cache=true,
    cache_parsed=true,
)
```

Use `cache_info()` to record cached source files and parsed outputs, and
`refresh=true` when you intentionally want to reparse or refresh metadata.

```julia
cache_info()

df = read_abs("6202.0"; tables=1, refresh=true)
```

Use `cache_parsed=false` for one-off checks where you do not want to reuse a
serialized parsed `DataFrame`.

```julia
df = read_abs("6202.0"; tables=1, cache_parsed=false)
```
