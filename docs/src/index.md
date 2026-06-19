# AustralianStatistics.jl

AustralianStatistics.jl is a Julia package for finding, downloading, reading, and tidying Australian Bureau of Statistics data.

It is designed around ordinary Julia workflows: functions return `DataFrame`s,
catalogue discovery is explicit, downloads are cached, and ABS time-series
workbooks are reshaped into tidy long-format observations.

The package has four main layers:

- Discovery: cached catalogue, file, release, cube, and API metadata indexes.
- Acquisition: cached workbook, cube, URL, and API downloads.
- Parsing: tidy time-series parsing, metadata extraction, cube parsing, and raw sheet reads.
- Workflow helpers: series lookup, series splitting, latest-date checks, and convenience readers.

## Core Workflows

```julia
using AustralianStatistics

search_abs("labour")

files("6202.0")

df = read_abs("6202.0"; tables=1)

metadata = read_metadata("6202.0"; tables=1)

series = read_series("A84423043A"; cat_no="6202.0")
```

## What The Package Covers

- Catalogue and file discovery with cached indexes.
- Downloading ABS time-series workbooks and data cubes.
- Reading catalogue numbers, direct URLs, local Excel files, vectors, and directories.
- Tidy parsing of ABS time-series spreadsheets.
- One-row-per-series metadata extraction.
- Series lookup by ABS series identifier.
- Historical release discovery and dated downloads where ABS archives expose them.
- Data cube reading as practical sheet-shaped tables.
- ABS API dataflow, datastructure, key construction, dimension filters, and observation reads.
- Cache inspection, parsed-data caching, and cleanup.
- Convenience readers for common ABS families.

## Output Style

Time-series workbook reads return tidy long-format data by default. Each row is one series-date observation with ABS metadata where available, including series id, unit, frequency, table information, collection month, and series start.

Data cubes are read as table-shaped `DataFrame`s because ABS cubes vary widely in layout.

Set `tidy=false` for raw workbook inspection, or use `read_metadata` when you
want one row per series rather than one row per observation.

## Tutorials

Start with [Getting Started](@ref), then use the focused tutorials for
discovery, table reading, metadata, series workflows, cubes, the ABS API,
convenience readers, caching, reproducibility, and migration from generic
workflows to convenience readers.

See the [API Reference](@ref api-reference) for complete docstrings.
