"""
    read_abs(path_or_url; sheet=nothing, tables=nothing, header_row=nothing, download_dir=tempdir())

Read an ABS spreadsheet into a `DataFrame`.

When `tables` is supplied, matching ABS time-series sheets are parsed into tidy
long format. When `sheet` and `tables` are omitted, the first worksheet is read
as a raw table.
"""
function read_abs(path_or_url::AbstractString; sheet=nothing, tables=nothing, header_row::Union{Int,Nothing}=nothing, download_dir::AbstractString=tempdir())
    path = _local_path(path_or_url; download_dir)

    XLSX.openxlsx(path) do xf
        sheetnames = XLSX.sheetnames(xf)

        if tables !== nothing
            selected = _matching_tables(sheetnames, tables)
            return _read_tables(xf, selected; header_row)
        end

        sheetname = something(sheet, first(sheetnames))
        return _read_sheet(xf[sheetname]; header_row)
    end
end

function _read_tables(xf, sheetnames; header_row::Union{Int,Nothing}=nothing)
    out = _empty_tidy_abs()

    for sheetname in sheetnames
        table = _tidy_sheet(xf[sheetname], sheetname)
        isempty(table) && continue
        append!(out, table)
    end

    return out
end

function _matching_tables(sheetnames, tables)
    requested = _table_requests(tables)
    matches = String[]

    for request in requested
        request_matches = [sheetname for sheetname in sheetnames if _table_matches(sheetname, request)]
        append!(matches, request_matches)
    end

    unique_matches = unique(matches)
    isempty(unique_matches) && throw(ArgumentError("no sheets matched tables $(collect(requested)); available sheets are: $(join(sheetnames, ", "))"))
    return unique_matches
end

function _table_requests(tables)
    if tables isa Integer || tables isa AbstractString
        return [tables]
    end

    return collect(tables)
end

function _table_matches(sheetname::AbstractString, request)
    sheet_key = _table_key(sheetname)
    request_key = _table_key(request)
    isempty(request_key) && return false

    sheet_key == request_key && return true
    occursin(request_key, sheet_key) && return true

    request_number = _table_number(request)
    request_number === nothing && return false

    return any(number -> number == request_number, _numbers_in_text(sheetname))
end

function _table_key(value)
    return replace(lowercase(strip(string(value))), r"\s+" => "")
end

function _table_number(value)
    value isa Integer && return Int(value)

    text = string(value)
    match_result = match(r"\d+", text)
    match_result === nothing && return nothing
    return parse(Int, match_result.match)
end

function _numbers_in_text(value)
    return [parse(Int, match.match) for match in eachmatch(r"\d+", string(value))]
end

"""
    read_abs_series(series_id; cat_no=nothing, cache=true)

Read rows for `series_id` from supported ABS catalogue workbooks. When `cat_no`
is omitted, all currently supported catalogues are searched.
"""
function read_abs_series(series_id::AbstractString; cat_no=nothing, cache::Bool=true)
    catalogues = cat_no === nothing ? _supported_catalogues() : [strip(string(cat_no))]
    out = _empty_tidy_abs()

    for catalogue in catalogues
        path = _catalogue_workbook(catalogue; cache)
        matches = _series_matches(tidy_abs(path), series_id)
        isempty(matches) || append!(out, matches)
    end

    return out
end

function _supported_catalogues()
    return sort(collect(keys(ABS_TIME_SERIES_WORKBOOKS)))
end

function _catalogue_workbook(cat_no::AbstractString; cache::Bool=true)
    if cache
        return download_abs(cat_no)
    end

    return download_abs(cat_no; dest=mktempdir(), force=true)
end

function _series_matches(df::DataFrame, series_id::AbstractString)
    isempty(df) && return df

    needle = lowercase(strip(series_id))
    keep = map(df.series_id) do candidate
        lowercase(strip(string(candidate))) == needle
    end

    return df[keep, :]
end

function _local_path(path_or_url::AbstractString; download_dir::AbstractString)
    if startswith(lowercase(path_or_url), "http://") || startswith(lowercase(path_or_url), "https://")
        return _download_file(path_or_url; dest=download_dir)
    end

    if haskey(ABS_TIME_SERIES_WORKBOOKS, strip(path_or_url))
        return download_abs(path_or_url)
    end

    return path_or_url
end

function _looks_like_series_column(name)
    text = lowercase(string(name))
    return occursin("series", text) || occursin("time", text) || occursin("date", text) || occursin("period", text)
end

function _empty_series_value(value)
    return ismissing(value) || isempty(strip(string(value)))
end
