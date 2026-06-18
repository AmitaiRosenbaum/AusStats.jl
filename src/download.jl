const ABS_BASE_URL = "https://www.abs.gov.au"

const ABS_TIME_SERIES_WORKBOOKS = Dict(
    "6202.0" => (
        title = "Labour Force, Australia",
        description = "Monthly labour force estimates including employment, unemployment, participation, hours worked, and related time series.",
        url = "https://www.abs.gov.au/statistics/labour/employment-and-unemployment/labour-force-australia/apr-2026/62020001.xlsx",
        filename = "6202.0_labour_force_table_001.xlsx",
        supported = true,
    ),
    "6401.0" => (
        title = "Consumer Price Index, Australia",
        description = "Quarterly consumer price inflation measures including CPI groups, capital cities, and analytical series.",
        url = "https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/consumer-price-index-australia/apr-2026/640101.xlsx",
        filename = "6401.0_cpi_table_001.xlsx",
        supported = true,
    ),
    "5206.0" => (
        title = "Australian National Accounts",
        description = "Quarterly national income, expenditure, product, GDP, and related national accounts time series.",
        url = "https://www.abs.gov.au/statistics/economy/national-accounts/australian-national-accounts-national-income-expenditure-and-product/mar-2026/5206001_Key_Aggregates.xlsx",
        filename = "5206.0_national_accounts_key_aggregates.xlsx",
        supported = true,
    ),
    "6345.0" => (
        title = "Wage Price Index, Australia",
        description = "Quarterly wage price indexes by sector, state, industry, and original/seasonally adjusted trend series.",
        url = "https://www.abs.gov.au/statistics/economy/price-indexes-and-inflation/wage-price-index-australia/mar-2026/63450Table2bto9b.xlsx",
        filename = "6345.0_wage_price_index_all_quarterly_series.xlsx",
        supported = true,
    ),
)

default_cache_dir() = joinpath(homedir(), ".cache", "AustralianStatistics")

"""
    download_abs(cat_no; dest=default_cache_dir(), force=false)

Download the latest supported ABS Excel time-series workbook for `cat_no` and
return the local path.
"""
function download_abs(cat_no::AbstractString; dest::AbstractString=default_cache_dir(), force::Bool=false)
    source = _workbook_source(cat_no)
    return _download_file(source.url; dest, filename=source.filename, force)
end

function _workbook_source(cat_no::AbstractString)
    key = strip(cat_no)
    if !haskey(ABS_TIME_SERIES_WORKBOOKS, key)
        supported = join(sort(collect(keys(ABS_TIME_SERIES_WORKBOOKS))), ", ")
        throw(ArgumentError("unsupported ABS catalogue number `$cat_no`; supported values are: $supported"))
    end

    return ABS_TIME_SERIES_WORKBOOKS[key]
end

function _download_file(url::AbstractString; dest::AbstractString=tempdir(), filename=nothing, force::Bool=false)
    mkpath(dest)

    target = joinpath(dest, something(filename, basename(split(url, '?'; limit=2)[1])))
    if isempty(basename(target))
        throw(ArgumentError("could not infer a filename from url; pass `filename`"))
    end

    if isfile(target) && !force
        return target
    end

    return Downloads.download(url, target)
end

"""
    search_abs(query)

Search the locally known ABS catalogue map.
"""
function search_abs(query::AbstractString)
    needle = lowercase(strip(query))
    matches = DataFrame(cat_no=String[], title=String[], description=String[], supported=Bool[])

    for cat_no in sort(collect(keys(ABS_TIME_SERIES_WORKBOOKS)))
        source = ABS_TIME_SERIES_WORKBOOKS[cat_no]
        haystack = lowercase(join((cat_no, source.title, source.description), " "))
        if isempty(needle) || occursin(needle, haystack)
            push!(matches, (cat_no, source.title, source.description, source.supported))
        end
    end

    return matches
end

"""
    search_abs(workbook, query; sheets=nothing)

Search cell text in an ABS workbook and return matching sheet, row, column, and value.
"""
function search_abs(workbook::AbstractString, query::AbstractString; sheets=nothing)
    needle = lowercase(query)
    matches = DataFrame(sheet=String[], row=Int[], column=Int[], value=String[])

    XLSX.openxlsx(workbook) do xf
        for sheetname in _selected_sheets(xf, sheets)
            sheet = xf[sheetname]
            rows = _sheet_rows(sheet)
            for (row_index, row) in enumerate(rows)
                for (column_index, value) in enumerate(row)
                    ismissing(value) && continue
                    text = string(value)
                    if occursin(needle, lowercase(text))
                        push!(matches, (sheetname, row_index, column_index, text))
                    end
                end
            end
        end
    end

    return matches
end
