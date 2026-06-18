# AustralianStatistics.jl

A small Julia package for downloading, discovering, and tidying official Australian Bureau of Statistics spreadsheet data.

## Installation

From a local checkout:

```julia
pkg> dev .
```

## Basic Usage

```julia
using AustralianStatistics

search_abs("labour")

path = download_abs("6202.0")

df = read_abs("6202.0"; tables=["1"])

tidy = tidy_abs(path)

series = read_abs_series("A84423043A"; cat_no="6202.0")
```

## Cache

```julia
default_cache_dir()
cache_info()
clear_cache!()
```

Currently supported catalogue numbers are:

- `6202.0` Labour Force, Australia
- `6401.0` Consumer Price Index, Australia
- `5206.0` Australian National Accounts
- `6345.0` Wage Price Index, Australia
