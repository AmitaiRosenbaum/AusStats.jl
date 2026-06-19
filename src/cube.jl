"""
    search_cubes(query; cat_no=nothing, refresh=false)

Search known ABS data cube files.
"""
function search_cubes(query::AbstractString; cat_no=nothing, refresh::Bool=false)
    df = cat_no === nothing ? files(; refresh) : files(cat_no; refresh)
    cubes = df[df.is_cube, :]
    needle = lowercase(strip(query))
    isempty(needle) && return cubes

    keep = map(eachrow(cubes)) do row
        haystack = lowercase(join((row.cat_no, row.title, row.description, row.file_title, row.table_title, row.filename), " "))
        occursin(needle, haystack)
    end

    return cubes[keep, :]
end

"""
    read_cube(source; cube=nothing, release=:latest, cache=true)

Read an ABS data cube from a catalogue number, URL, or local workbook path.
Data cubes are returned as practical sheet-shaped `DataFrame`s with a `sheet`
column.
"""
function read_cube(source::AbstractString; cube=nothing, release=:latest, cache::Bool=true)
    path = if _is_url(source)
        dest = cache ? _cache_subdir(:cubes) : mktempdir()
        _download_file(source; dest, force=!cache)
    elseif isfile(source)
        source
    else
        cache ? download_cube(source; cube, release) :
            _download_file(_select_file(source; file=cube, release, cube=true).url; dest=mktempdir(), force=true)
    end

    return _read_cube_workbook(path)
end

function _read_cube_workbook(path::AbstractString)
    out = DataFrame()

    XLSX.openxlsx(path) do xf
        for sheetname in XLSX.sheetnames(xf)
            table = _read_sheet(xf[sheetname])
            isempty(table) && continue
            table[!, :sheet] = fill(sheetname, nrow(table))
            if isempty(out)
                out = table
            else
                append!(out, table; cols=:union)
            end
        end
    end

    return out
end
