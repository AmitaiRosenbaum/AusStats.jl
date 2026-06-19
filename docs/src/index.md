# AustralianStatistics.jl

AustralianStatistics.jl is a small Julia package for downloading, discovering, and tidying official Australian Bureau of Statistics spreadsheet data.

It focuses on pragmatic access to ABS Excel time-series workbooks. The package does not yet implement SDMX, live API discovery, or a provider abstraction. Instead, it provides a simple catalogue map for a small set of high-value ABS publications and tools for turning their spreadsheets into tidy `DataFrame`s.

## What It Does

- Search the locally supported ABS catalogue map.
- Download supported ABS Excel workbooks into a package cache.
- Read workbook sheets into `DataFrame`s.
- Convert ABS time-series spreadsheets into tidy long-form data.
- Find a series by `series_id` across one or all supported catalogues.
- Inspect and clear the local cache.

## Supported Catalogues

The current catalogue map is intentionally small:

| Catalogue | Publication |
| --- | --- |
| `6202.0` | Labour Force, Australia |
| `6401.0` | Consumer Price Index, Australia |
| `5206.0` | Australian National Accounts |
| `6345.0` | Wage Price Index, Australia |

## Installation

From a local checkout:

```julia
pkg> dev .
```

Then load the package:

```julia
using AustralianStatistics
```

## Quick Example

```julia
using AustralianStatistics

search_abs("labour")

path = download_abs("6202.0")

raw = read_abs("6202.0"; tables=["1"])

tidy = tidy_abs(path)

series = read_abs_series("A84423043A"; cat_no="6202.0")
```

## Public API

The exported API is deliberately small:

- [`search_abs`](@ref)
- [`download_abs`](@ref)
- [`read_abs`](@ref)
- [`tidy_abs`](@ref)
- [`read_abs_series`](@ref)
- [`default_cache_dir`](@ref)
- [`cache_info`](@ref)
- [`clear_cache!`](@ref)

See the [API Reference](@ref api-reference) for complete docstrings.
