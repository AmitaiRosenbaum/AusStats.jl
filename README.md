# AustralianStatistics.jl

AustralianStatistics.jl helps Julia users find, download, read, and tidy Australian Bureau of Statistics data.

The package is DataFrame-first and focuses on practical workflows:

- discover ABS catalogues and downloadable files
- download cached ABS time-series workbooks and data cubes
- read catalogue numbers, local files, and direct URLs
- reshape ABS time-series workbooks into tidy long-format data
- inspect series metadata and retrieve individual series
- query ABS API endpoints into DataFrames

## Installation

From a local checkout:

```julia
pkg> dev .
```

## Examples

```julia
using AustralianStatistics

search_abs("labour")

catalogues()

files("6202.0")

path = download_abs("6202.0")

df = read_abs("6202.0"; tables=1)

metadata = read_metadata("6202.0"; tables=1)

series = read_series("A84423043A"; cat_no="6202.0")
```

Read local files or URLs with the same tidy parser:

```julia
read_abs_local(path; tables=1)

read_abs_url("https://www.abs.gov.au/path/to/workbook.xlsx"; tables=1)
```

Work with data cubes:

```julia
search_cubes("labour"; cat_no="6202.0")

cube = read_cube("path/to/cube.xlsx")
```

Use the ABS API:

```julia
flows = dataflows()

structure = datastructure("CPI")

observations = read_api("CPI"; start_period="2024-Q1")
```

## Cache

```julia
default_cache_dir()
cache_info()
clear_cache!(:workbooks)
clear_cache!()
```

Network-backed discovery and online integration tests are optional. Offline workflows continue to use cached indexes/files and bundled seed catalogue entries.
