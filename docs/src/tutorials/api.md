# ABS API

AustralianStatistics.jl includes a small ABS API client for workflows where spreadsheet files are not the best fit.

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

Build an API key from dimension filters:

```julia
key = api_key("CPI"; filters=(measure="1", region="0"))
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
    filters=(measure="1", region="0"),
    start_period="2024-Q1",
)
```

Use `key` when you know the ABS API key:

```julia
observations = read_api("CPI"; key="1.10001.10.50.Q", start_period="2024-Q1")
```

For large API requests, narrow the query with `filters`, `start_period`, and
`end_period`. The `params` keyword is passed through to the ABS API for advanced
calls.

## Read A Direct API URL

```julia
observations = read_api_url("https://data.api.abs.gov.au/rest/data/ABS/CPI/all/all?startPeriod=2024-Q1")
```

API reads return tidy `DataFrame`s with observation values, period information, and dimension columns where available.
