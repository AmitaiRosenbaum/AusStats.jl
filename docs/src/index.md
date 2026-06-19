# AustralianStatistics.jl

AustralianStatistics.jl is a Julia package for finding, downloading, reading, and tidying Australian Bureau of Statistics data.

It is designed around ordinary Julia workflows: functions return `DataFrame`s, catalogue discovery is explicit, downloads are cached, and ABS time-series workbooks are reshaped into tidy long-format observations.

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
- Reading catalogue numbers, direct URLs, and local Excel files.
- Tidy parsing of ABS time-series spreadsheets.
- One-row-per-series metadata extraction.
- Series lookup by ABS series identifier.
- Data cube reading as practical sheet-shaped tables.
- ABS API dataflow, datastructure, and observation reads.
- Cache inspection and cleanup.

## Output Style

Time-series workbook reads return tidy long-format data by default. Each row is one series-date observation with ABS metadata where available, including series id, unit, frequency, table information, collection month, and series start.

Data cubes are read as table-shaped `DataFrame`s because ABS cubes vary widely in layout.

## Tutorials

Start with [Getting Started](@ref), then use the focused tutorials for discovery, table reading, metadata, series workflows, cubes, the ABS API, and cache management.

See the [API Reference](@ref api-reference) for complete docstrings.
