# Reading Tables

ABS time-series workbooks often contain many sheets. [`read_abs`](@ref) provides a forgiving `tables` filter so you can select sheets without knowing the exact workbook name.

## Tidy Reads

Tidy reads are the default:

```julia
df = read_abs("6202.0"; tables=1)
```

The output is long-format time-series data with source table and sheet metadata.

## Forgiving Table Matching

The `tables` keyword:

- is case-insensitive
- ignores spaces
- accepts integers or strings
- matches table numbers embedded in sheet names

These are equivalent for a workbook with a `Data1` sheet:

```julia
read_abs("6202.0"; tables=["1"])
read_abs("6202.0"; tables=["Table 1"])
read_abs("6202.0"; tables=["Data1"])
read_abs("6202.0"; tables=1)
```

Read multiple tables by passing a vector:

```julia
df = read_abs("6202.0"; tables=[1, 2])
```

## Catalogue Numbers, Local Files, And URLs

Use the same workflow for supported source types:

```julia
read_abs("6202.0"; tables=1)

path = download_abs("6202.0")
read_abs_local(path; tables=1)

read_abs_url("https://www.abs.gov.au/path/to/workbook.xlsx"; tables=1)
```

## Raw Sheet Reads

Set `tidy=false` to read the first matched sheet as a raw table.

```julia
raw = read_abs("6202.0"; tables=1, tidy=false)
```

Raw reads are useful when you are inspecting an unfamiliar workbook layout.
