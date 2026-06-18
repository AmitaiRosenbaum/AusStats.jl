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
    read_abs_series(path_or_url; sheet=nothing, header_row=nothing, download_dir=tempdir())

Read an ABS spreadsheet and keep rows that look like time-series observations.
"""
function read_abs_series(path_or_url::AbstractString; sheet=nothing, header_row::Union{Int,Nothing}=nothing, download_dir::AbstractString=tempdir())
    df = read_abs(path_or_url; sheet, header_row, download_dir)
    isempty(df) && return df

    series_columns = [name for name in names(df) if _looks_like_series_column(name)]
    isempty(series_columns) && return df

    keep = map(eachrow(df)) do row
        any(name -> !_empty_series_value(row[name]), series_columns)
    end

    return df[keep, :]
end

function _local_path(path_or_url::AbstractString; download_dir::AbstractString)
    if startswith(lowercase(path_or_url), "http://") || startswith(lowercase(path_or_url), "https://")
        return download_abs(path_or_url; dir=download_dir)
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
