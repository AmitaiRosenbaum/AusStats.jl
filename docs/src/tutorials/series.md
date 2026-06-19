# Working With Series

ABS time-series workbooks store observations alongside series metadata. AustralianStatistics.jl focuses on converting those spreadsheets into tidy long-form data.

## Tidy a Workbook

Download a workbook and tidy it:

```julia
path = download_abs("6401.0")
tidy = tidy_abs(path)
```

The result is a `DataFrame` with one row per observation where possible.

## Metadata Columns

[`tidy_abs`](@ref) extracts the following columns where available:

| Column | Meaning |
| --- | --- |
| `table` | source worksheet name |
| `date` | period start as a `Date` |
| `series_id` | ABS series identifier |
| `value` | numeric observation as `Float64` or `missing` |
| `unit` | unit of measure |
| `series_type` | series type, such as seasonally adjusted or original, where available |
| `data_type` | ABS data type, where available |
| `frequency` | `monthly`, `quarterly`, `annual`, or `unknown` |
| `series` | series description or data item |

## Period Parsing

ABS period labels are converted to period-start dates.

Examples:

| Input | Frequency | Date |
| --- | --- | --- |
| `Jan-2024` | `monthly` | `2024-01-01` |
| `2024-01` | `monthly` | `2024-01-01` |
| `Mar-2024` | `quarterly`, when cadence is quarterly | `2024-01-01` |
| `2024-Q1` | `quarterly` | `2024-01-01` |
| `Q1 2024` | `quarterly` | `2024-01-01` |
| `2024` | `annual` | `2024-01-01` |

## Read One Series

If you know the ABS series id, use [`read_abs_series`](@ref):

```julia
series = read_abs_series("A84423043A"; cat_no="6202.0")
```

This downloads or reuses the cached workbook for `6202.0`, tidies the workbook, and returns matching rows.

Matching is case-insensitive:

```julia
series = read_abs_series("a84423043a"; cat_no="6202.0")
```

## Search All Supported Catalogues

Omit `cat_no` to search all supported catalogues:

```julia
series = read_abs_series("A84423043A")
```

This is convenient, but slower than providing `cat_no` because each supported catalogue may need to be downloaded and parsed.

## Cache Control

By default, [`read_abs_series`](@ref) uses cached workbooks:

```julia
series = read_abs_series("A84423043A"; cat_no="6202.0", cache=true)
```

Set `cache=false` to download into a temporary directory for that call:

```julia
series = read_abs_series("A84423043A"; cat_no="6202.0", cache=false)
```
