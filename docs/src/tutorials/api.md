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

The result lists dimensions where they can be discovered from the ABS API response.

## Read API Observations

```julia
observations = read_api("CPI"; start_period="2024-Q1")
```

Use `key` when you know the ABS API key:

```julia
observations = read_api("CPI"; key="1.10001.10.50.Q", start_period="2024-Q1")
```

## Read A Direct API URL

```julia
observations = read_api_url("https://data.api.abs.gov.au/rest/data/ABS/CPI/all/all?startPeriod=2024-Q1")
```

API reads return tidy `DataFrame`s with observation values, period information, and dimension columns where available.
