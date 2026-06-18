function _selected_sheets(xf, sheets)
    available = XLSX.sheetnames(xf)
    sheets === nothing && return available
    sheets isa AbstractString && return [sheets]
    return collect(sheets)
end

function _read_sheet(sheet; header_row::Union{Int,Nothing}=nothing)
    rows = _sheet_rows(sheet)
    isempty(rows) && return DataFrame()

    first_data_row = something(header_row, _detect_header_row(rows))
    names = _column_names(rows[first_data_row])
    data_rows = rows[(first_data_row + 1):end]

    table = DataFrame([name => Any[] for name in names])
    for row in data_rows
        _row_is_empty(row) && continue
        values = Any[_clean_cell(get(row, i, missing)) for i in eachindex(names)]
        push!(table, values)
    end

    return table
end

function _sheet_rows(sheet)
    data = XLSX.getdata(sheet)
    isempty(data) && return Vector{Vector{Any}}()
    return [Any[_cell_value(data[row, column]) for column in axes(data, 2)] for row in axes(data, 1)]
end

function _cell_value(value)
    return value === nothing ? missing : value
end

function _detect_header_row(rows)
    scores = map(rows) do row
        count(value -> !ismissing(value) && !isempty(strip(string(value))), row)
    end
    index = findfirst(>(1), scores)
    return something(index, 1)
end

function _column_names(row)
    names = String[]
    seen = Dict{String,Int}()

    for (index, value) in enumerate(row)
        base = if ismissing(value) || isempty(strip(string(value)))
            "Column$index"
        else
            _normalise_name(string(value))
        end

        count = get(seen, base, 0) + 1
        seen[base] = count
        push!(names, count == 1 ? base : "$(base)_$count")
    end

    return Symbol.(names)
end

function _normalise_name(value::AbstractString)
    cleaned = replace(strip(value), r"\s+" => "_")
    cleaned = replace(cleaned, r"[^A-Za-z0-9_]" => "")
    return isempty(cleaned) ? "Column" : cleaned
end

function _row_is_empty(row)
    return all(value -> ismissing(value) || isempty(strip(string(value))), row)
end

function _clean_cell(value)
    ismissing(value) && return missing
    value isa Date && return value
    value isa DateTime && return Date(value)
    return value
end
