# AusStats.jl

[![Stable documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://AmitaiRosenbaum.github.io/AusStats.jl/stable)
[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://AmitaiRosenbaum.github.io/AusStats.jl/dev)
[![codecov](https://codecov.io/gh/AmitaiRosenbaum/AusStats.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/AmitaiRosenbaum/AusStats.jl)
[![CI](https://github.com/AmitaiRosenbaum/AusStats.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/AmitaiRosenbaum/AusStats.jl/actions/workflows/ci.yml)
[![Format](https://github.com/AmitaiRosenbaum/AusStats.jl/actions/workflows/format.yml/badge.svg)](https://github.com/AmitaiRosenbaum/AusStats.jl/actions/workflows/format.yml)
[![Aqua QA](https://juliatesting.github.io/Aqua.jl/dev/assets/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![](https://img.shields.io/badge/%F0%9F%9B%A9%EF%B8%8F_tested_with-JET.jl-233f9a)](https://github.com/aviatesk/JET.jl)

AusStats.jl is a Julia package for finding, downloading, reading, and tidying
Australian Bureau of Statistics data.

It is designed for DataFrame-first workflows: discover ABS publications, cache
downloads, parse time-series workbooks into tidy observations, read data cubes,
query ABS API endpoints, and keep reproducible local workflows around ABS data.

## Why AusStats.jl?

- Work with ABS catalogue numbers, direct URLs, local Excel files, directories,
  data cubes, and API responses through one package.
- Get tidy `DataFrame` outputs for time-series workbooks, with ABS metadata
  preserved where available.
- Cache downloaded and parsed data so repeated work is fast and reproducible.
- Use generic readers for flexible workflows, or convenience readers for common
  publication families.
- Keep network-dependent tests optional while the core package remains covered
  by deterministic offline fixtures.

## Quick Start

```julia
using AusStats

search_abs("labour")
files("6202.0")

df = read_abs("6202.0"; tables=1)
metadata = read_metadata("6202.0"; tables=1)
series = read_series("A84423043A"; cat_no="6202.0")
```

## Examples

Download and read a current ABS workbook:

```julia
path = download_abs("6202.0")
df = read_abs_local(path; tables=1)
```

Read a historical release when ABS exposes the release archive:

```julia
using Dates

historical = read_abs("6345.0"; release=Date(2019, 9, 1), tables=1)
```

Work with a data cube or the ABS API:

```julia
cube = read_cube("6202.0"; cube="gross flows")

structure = datastructure("CPI")
observations = read_api("CPI"; filters=(measure="1",), start_period="2024-Q1")
```

Use convenience readers for common publication families:

```julia
cpi = read_cpi(; table=1)
grossflows = read_lfs_grossflows()
```

For installation, tutorials, API reference, caching details, local-file
workflows, data cubes, ABS API usage, and convenience readers, see the
[documentation](https://AmitaiRosenbaum.github.io/AusStats.jl/dev).

## Disclaimer

The `AusStats.jl` package is not associated with the Australian Bureau of Statistics. All data is provided subject to any restrictions and licensing arrangements noted on the ABS website.

## Attribution

This project was inspired by the [`readabs`](https://github.com/MattCowgill/readabs) R package.
