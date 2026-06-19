# Working With Series

ABS time-series workbooks identify each series with a stable series id. AustralianStatistics.jl keeps that identifier in the `series_id` column.

## Read A Known Series

```julia
series = read_series("A84423043A"; cat_no="6202.0")
```

Matching is case-insensitive:

```julia
series = read_series("a84423043a"; cat_no="6202.0")
```

Pass multiple identifiers to return all matching observations:

```julia
series = read_series(["A84423043A", "B84423043B"]; cat_no="6202.0")
```

## Search Across Catalogues

Omit `cat_no` to search all known catalogues:

```julia
series = read_series("A84423043A")
```

This can be slower because each known catalogue may need to be downloaded and parsed.

## Split Series Labels

ABS series descriptions can contain several pieces of information in one string. [`separate_series`](@ref) adds simple component columns.

```julia
df = read_abs("6202.0"; tables=1)

expanded = separate_series(df)
```

## Latest Observation Date

Use [`latest_date`](@ref) to check the latest available period in a result:

```julia
latest_date(df)
```
