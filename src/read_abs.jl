"""
    read_abs(path_or_url; sheet=nothing, header_row=nothing, download_dir=tempdir())

Read an ABS spreadsheet into a `DataFrame`. When `sheet` is omitted, the first
worksheet is read.
"""
function read_abs(path_or_url::AbstractString; sheet=nothing, header_row::Union{Int,Nothing}=nothing, download_dir::AbstractString=tempdir())
    path = _local_path(path_or_url; download_dir)

    XLSX.openxlsx(path) do xf
        sheetname = something(sheet, first(XLSX.sheetnames(xf)))
        return _read_sheet(xf[sheetname]; header_row)
    end
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

    return path_or_url
end

function _looks_like_series_column(name)
    text = lowercase(string(name))
    return occursin("series", text) || occursin("time", text) || occursin("date", text) || occursin("period", text)
end

function _empty_series_value(value)
    return ismissing(value) || isempty(strip(string(value)))
end
