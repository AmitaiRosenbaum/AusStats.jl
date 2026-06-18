const ABS_BASE_URL = "https://www.abs.gov.au"

"""
    download_abs(url; dir=tempdir(), filename=nothing, overwrite=false)

Download an ABS spreadsheet or other ABS resource and return the local path.
"""
function download_abs(url::AbstractString; dir::AbstractString=tempdir(), filename=nothing, overwrite::Bool=false)
    mkpath(dir)

    target = joinpath(dir, something(filename, basename(split(url, '?'; limit=2)[1])))
    if isempty(basename(target))
        throw(ArgumentError("could not infer a filename from url; pass `filename`"))
    end

    if isfile(target) && !overwrite
        return target
    end

    return Downloads.download(url, target)
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
