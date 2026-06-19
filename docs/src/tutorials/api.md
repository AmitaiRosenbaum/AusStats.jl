# ABS API

AusStats.jl includes a small ABS API client for workflows where spreadsheet files are not the best fit.

## List Dataflows

```julia
flows = dataflows()
```

Refresh cached API metadata:

```julia
flows = dataflows(; refresh=true)
```

## Inspect A Datastructure

```julia
structure = datastructure("CPI")
```

The result lists dimensions and code labels where they can be discovered from
the ABS API response. Use it to find valid filter names and codes before reading
observations.

Useful columns include dimension identifiers, names, positions, code values, and
code labels. Exact dimensions vary by ABS API flow.

Build an API key from dimension filters:

```julia
key = api_key("CPI"; filters=(measure="1",))
```

## Read API Observations

```julia
observations = read_api("CPI"; start_period="2024-Q1")
```

Use `filters` to build the API key from named dimensions. Filter names are
matched against datastructure dimensions, and codes are validated where possible.

```julia
observations = read_api(
    "CPI";
    filters=(measure="1",),
    start_period="2024-Q1",
    end_period="2024-Q4",
)
```

Use `key` when you know the ABS API key:

```julia
observations = read_api("CPI"; key="1.10001.10.50.Q", start_period="2024-Q1")
```

For large API requests, narrow the query with `filters`, `start_period`, and
`end_period`. The `params` keyword is passed through to the ABS API for advanced
calls.

```julia
observations = read_api(
    "CPI";
    filters=(measure="1",),
    params=(dimension_at_observation="AllDimensions",),
)
```

If the ABS API returns a large-query or timeout-style error,
AusStats.jl rethrows it with guidance to narrow filters or periods.

## Read A Direct API URL

```julia
observations = read_api_url("https://data.api.abs.gov.au/rest/data/ABS/CPI/all/all?startPeriod=2024-Q1")
```

API reads return tidy `DataFrame`s with observation values, period information, and dimension columns where available.
