"""
    dataflows(; refresh=false)

Return ABS API dataflows as a `DataFrame`.
"""
function dataflows(; refresh::Bool=false)
    path = joinpath(_cache_subdir(:api), "dataflows.json")
    if refresh || !isfile(path)
        url = ABS_API_BASE_URL * "/dataflow/ABS/all/latest?references=none"
        mkpath(dirname(path))
        write(path, String(_http_get(url; accept="application/vnd.sdmx.structure+json,application/json,*/*").body))
    end

    return _dataflows_dataframe(JSON3.read(read(path, String)))
end

"""
    datastructure(flow_id; refresh=false)

Return the dimensions and code values advertised by the ABS API datastructure
for `flow_id`.
"""
function datastructure(flow_id::AbstractString; refresh::Bool=false)
    path = _datastructure_cache_path(flow_id)
    if refresh || !isfile(path)
        url = ABS_API_BASE_URL * "/datastructure/ABS/" * HTTP.escapeuri(flow_id) * "/all/latest?references=all"
        mkpath(dirname(path))
        write(path, String(_http_get(url; accept="application/vnd.sdmx.structure+json,application/json,*/*").body))
    end

    return _datastructure_dataframe(JSON3.read(read(path, String)))
end

"""
    api_key(flow_id; filters=NamedTuple(), refresh=false)

Build an ABS API key for `flow_id` from named dimension filters. Filter names
and codes are validated against [`datastructure`](@ref) where possible.
"""
function api_key(flow_id::AbstractString; filters=NamedTuple(), refresh::Bool=false)
    filter_pairs = _filter_pairs(filters)
    isempty(filter_pairs) && return "all"

    structure = datastructure(flow_id; refresh)
    dimensions = _api_dimensions(structure)
    isempty(dimensions) && throw(ArgumentError("datastructure for `$flow_id` did not include dimensions; pass an explicit `key` to `read_api`"))

    matched = Dict{String,Any}()
    for (name, value) in filter_pairs
        row = _match_api_dimension(dimensions, name)
        row === nothing && throw(ArgumentError(_unknown_filter_message(name, dimensions)))
        matched[row.dimension_id] = value
    end

    segments = String[]
    for row in eachrow(dimensions)
        if haskey(matched, row.dimension_id)
            push!(segments, _api_key_segment(structure, row.dimension_id, matched[row.dimension_id]))
        else
            push!(segments, "")
        end
    end

    return join(segments, ".")
end

"""
    read_api(flow_id; key=nothing, filters=NamedTuple(), start_period=nothing, end_period=nothing, params=NamedTuple())

Read observations from the ABS API and return a tidy `DataFrame`.
"""
function read_api(flow_id::AbstractString; key=nothing, filters=NamedTuple(), start_period=nothing, end_period=nothing, params=NamedTuple())
    url = _api_request_url(flow_id; key, filters, start_period, end_period, params)
    return read_api_url(url)
end

function _api_request_url(flow_id::AbstractString; key=nothing, filters=NamedTuple(), start_period=nothing, end_period=nothing, params=NamedTuple())
    filter_pairs = _filter_pairs(filters)
    key !== nothing && !isempty(filter_pairs) && throw(ArgumentError("pass either an explicit `key` or `filters`, not both"))

    query = Dict{String,String}()
    start_period === nothing || (query["startPeriod"] = string(start_period))
    end_period === nothing || (query["endPeriod"] = string(end_period))
    for pair in pairs(params)
        query[string(first(pair))] = string(last(pair))
    end

    query_text = isempty(query) ? "" : "?" * join([HTTP.escapeuri(k) * "=" * HTTP.escapeuri(v) for (k, v) in sort(collect(query))], "&")
    resolved_key = key === nothing ? api_key(flow_id; filters) : string(key)
    return ABS_API_BASE_URL * "/data/ABS/" * HTTP.escapeuri(flow_id) * "/" * HTTP.escapeuri(resolved_key) * "/all" * query_text
end

"""
    read_api_url(url)

Read an ABS API URL and return observations as a tidy `DataFrame`.
"""
function read_api_url(url::AbstractString)
    try
        return _sdmx_data_to_dataframe(_http_json(url))
    catch error
        error isa InterruptException && throw(error)
        message = sprint(showerror, error)
        if occursin("HTTP 400", message) || occursin("HTTP 413", message) || occursin("HTTP 414", message) ||
                occursin("HTTP 429", message) || occursin("HTTP 500", message) || occursin("HTTP 502", message) ||
                occursin("HTTP 503", message) || occursin("HTTP 504", message) || occursin("timed out", lowercase(message))
            throw(ABSError("$message Narrow large ABS API queries with `filters`, `start_period`, or `end_period`."))
        end
        rethrow(error)
    end
end

function _dataflows_dataframe(json)
    flows = Any[]
    _collect_named_objects!(flows, json, ("dataflows", "Dataflows"))
    rows = DataFrame(id=String[], name=String[], description=String[])

    for flow in flows
        id = _json_string(flow, "id")
        name = _json_name(flow)
        description = _json_description(flow)
        isempty(id) || push!(rows, (id, name, description))
    end

    return unique(rows)
end

function _datastructure_dataframe(json)
    codelists = _datastructure_codelists(json)
    out = DataFrame(
        dimension_id = String[],
        dimension_name = String[],
        position = Int[],
        code = Union{Missing,String}[],
        label = Union{Missing,String}[],
        code_position = Union{Missing,Int}[],
    )

    for dimension in _datastructure_dimensions(json)
        id = _json_string(dimension, "id")
        isempty(id) && continue
        dimension_name = _json_name(dimension)
        position = _dimension_position(dimension, length(unique(out.dimension_id)) + 1)
        values = _dimension_code_values(dimension, codelists)

        if isempty(values)
            push!(out, (id, dimension_name, position, missing, missing, missing))
        else
            for (code_position, value) in enumerate(values)
                code = _json_string(value, "id")
                label = _json_name(value)
                push!(out, (id, dimension_name, position, code, isempty(label) ? missing : label, code_position))
            end
        end
    end

    return unique(sort(out, [:position, :code_position]))
end

function _datastructure_cache_path(flow_id::AbstractString)
    return joinpath(_cache_subdir(:api), "datastructure_$(lowercase(_safe_filename(flow_id))).json")
end

function _datastructure_dimensions(json)
    dimensions = Any[]

    for path in (
        ("data", "dataStructures", 1, "dataStructureComponents", "dimensionList", "dimensions"),
        ("dataStructures", 1, "dataStructureComponents", "dimensionList", "dimensions"),
        ("structure", "dimensions", "series"),
        ("structure", "dimensions", "observation"),
    )
        value = _json_path(json, path...)
        if value isa AbstractVector || value isa JSON3.Array
            append!(dimensions, collect(value))
        end
    end

    if isempty(dimensions)
        collected = Any[]
        _collect_named_objects!(collected, json, ("dimensions", "Dimensions"))
        for value in collected
            if value isa AbstractVector || value isa JSON3.Array
                append!(dimensions, collect(value))
            elseif value isa AbstractDict || value isa JSON3.Object
                id = _json_string(value, "id")
                isempty(id) || push!(dimensions, value)
            end
        end
    end

    return dimensions
end

function _datastructure_codelists(json)
    out = Dict{String,Any}()
    codelists = Any[]
    _collect_named_objects!(codelists, json, ("codelists", "Codelists"))

    for item in codelists
        if item isa AbstractVector || item isa JSON3.Array
            for codelist in item
                id = _json_string(codelist, "id")
                isempty(id) || (out[id] = codelist)
            end
        elseif item isa AbstractDict || item isa JSON3.Object
            if !isempty(_json_string(item, "id"))
                out[_json_string(item, "id")] = item
            else
                for pair in pairs(item)
                    codelist = last(pair)
                    id = _json_string(codelist, "id")
                    isempty(id) || (out[id] = codelist)
                end
            end
        end
    end

    return out
end

function _dimension_position(dimension, fallback::Int)
    value = _json_get(dimension, "position", nothing)
    value === nothing && return fallback
    value isa Integer && return Int(value) + 1
    parsed = tryparse(Int, string(value))
    parsed === nothing ? fallback : parsed + 1
end

function _dimension_code_values(dimension, codelists::Dict{String,Any}=Dict{String,Any}())
    values = _json_get(dimension, "values", Any[])
    (values isa AbstractVector || values isa JSON3.Array) && !isempty(values) && return collect(values)

    local_representation = _json_get(dimension, "localRepresentation", nothing)
    enumeration = local_representation === nothing ? nothing : _json_get(local_representation, "enumeration", nothing)
    codelist_id = enumeration === nothing ? "" : _json_string(enumeration, "id")
    if isempty(codelist_id)
        ref = enumeration === nothing ? "" : _json_string(enumeration, "ref")
        codelist_id = ref
    end

    if !isempty(codelist_id) && haskey(codelists, codelist_id)
        codes = _json_get(codelists[codelist_id], "items", Any[])
        (codes isa AbstractVector || codes isa JSON3.Array) && !isempty(codes) && return collect(codes)
        codes = _json_get(codelists[codelist_id], "codes", Any[])
        (codes isa AbstractVector || codes isa JSON3.Array) && return collect(codes)
    end

    return Any[]
end

function _api_dimensions(structure::DataFrame)
    required = (:dimension_id, :dimension_name, :position)
    all(name -> hasproperty(structure, name), required) || throw(ArgumentError("datastructure result does not include API dimension metadata"))
    return unique(sort(structure[:, [:dimension_id, :dimension_name, :position]], :position))
end

function _filter_pairs(filters)
    filters === nothing && return Pair{Symbol,Any}[]
    if filters isa NamedTuple
        return [Symbol(name) => value for (name, value) in pairs(filters)]
    elseif filters isa AbstractDict
        return [Symbol(name) => value for (name, value) in pairs(filters)]
    end

    throw(ArgumentError("filters must be a NamedTuple or dictionary"))
end

function _match_api_dimension(dimensions::DataFrame, name::Symbol)
    key = _api_filter_key(String(name))
    for row in eachrow(dimensions)
        _api_filter_key(row.dimension_id) == key && return row
        _api_filter_key(row.dimension_name) == key && return row
    end
    return nothing
end

function _unknown_filter_message(name::Symbol, dimensions::DataFrame)
    available = join(["$(row.dimension_id)" for row in eachrow(dimensions)], ", ")
    return "unknown API filter `$(name)`; available filters are: $available"
end

function _api_key_segment(structure::DataFrame, dimension_id::AbstractString, value)
    codes = value isa AbstractVector && !(value isa AbstractString) ? collect(value) : [value]
    isempty(codes) && return ""
    return join([_api_code_for_dimension(structure, dimension_id, code) for code in codes], "+")
end

function _api_code_for_dimension(structure::DataFrame, dimension_id::AbstractString, code)
    requested = strip(string(code))
    isempty(requested) && return ""

    rows = structure[structure.dimension_id .== dimension_id, :]
    valid_rows = rows[.!ismissing.(rows.code), :]
    isempty(valid_rows) && return requested

    for row in eachrow(valid_rows)
        lowercase(string(row.code)) == lowercase(requested) && return string(row.code)
        !ismissing(row.label) && _api_filter_key(row.label) == _api_filter_key(requested) && return string(row.code)
    end

    examples = join(first(string.(valid_rows.code), min(nrow(valid_rows), 8)), ", ")
    throw(ArgumentError("invalid code `$requested` for API dimension `$dimension_id`; valid codes include: $examples"))
end

function _api_filter_key(value)
    return replace(lowercase(strip(string(value))), r"[^a-z0-9]+" => "")
end

function _sdmx_data_to_dataframe(json)
    dimensions = _sdmx_dimensions(json)
    obs_dimension = get(dimensions, "observation", Any[])
    series_dimensions = get(dimensions, "series", Any[])
    datasets = _json_get(json, "dataSets", Any[])

    out = DataFrame()
    out[!, :period] = String[]
    out[!, :date] = Union{Missing,Date}[]
    out[!, :value] = Union{Missing,Float64}[]

    isempty(datasets) && return out

    for dataset in datasets
        series = _json_get(dataset, "series", Dict())
        for pair in pairs(series)
            series_key = string(first(pair))
            series_values = _dimension_values(series_dimensions, series_key)
            observations = _json_get(last(pair), "observations", Dict())

            for observation_pair in pairs(observations)
                obs_key = string(first(observation_pair))
                obs_values = _dimension_values(obs_dimension, obs_key)
                obs = last(observation_pair)
                value = obs isa AbstractVector && !isempty(obs) ? _parse_abs_float(first(obs)) : _parse_abs_float(obs)
                period = get(obs_values, "TIME_PERIOD", get(obs_values, "time", obs_key))
                row = Dict{Symbol,Any}(:period => string(period), :date => something(_parse_abs_date(period), missing), :value => value)
                for (name, dim_value) in merge(series_values, obs_values)
                    row[Symbol(name)] = dim_value
                end
                push!(out, row; cols=:union)
            end
        end
    end

    return out
end

function _sdmx_dimensions(json)
    structure = _json_get(json, "structure", Dict())
    dimensions = _json_get(structure, "dimensions", Dict())
    return Dict(string(first(pair)) => last(pair) for pair in pairs(dimensions))
end

function _dimension_values(dimensions, key::AbstractString)
    indexes = isempty(key) ? String[] : split(key, ":")
    out = Dict{String,String}()

    for (position, dimension) in enumerate(dimensions)
        position <= length(indexes) || continue
        index = tryparse(Int, indexes[position])
        index === nothing && continue
        values = _json_get(dimension, "values", Any[])
        1 <= index + 1 <= length(values) || continue
        id = _json_string(dimension, "id")
        value = values[index + 1]
        out[id] = _json_string(value, "id")
    end

    return out
end

function _collect_named_objects!(out, json, keys)
    if json isa AbstractDict || json isa JSON3.Object
        for pair in pairs(json)
            key = string(first(pair))
            value = last(pair)
            if key in keys
                if value isa AbstractVector
                    append!(out, value)
                elseif value isa AbstractDict || value isa JSON3.Object
                    append!(out, [last(pair) for pair in pairs(value)])
                else
                    push!(out, value)
                end
            else
                _collect_named_objects!(out, value, keys)
            end
        end
    elseif json isa AbstractVector
        for item in json
            _collect_named_objects!(out, item, keys)
        end
    end
    return out
end

function _json_get(obj, key::AbstractString, default=nothing)
    if obj isa AbstractDict
        return get(obj, key, default)
    elseif obj isa JSON3.Object
        sym = Symbol(key)
        return hasproperty(obj, sym) ? getproperty(obj, sym) : default
    end
    return default
end

function _json_path(obj, path...)
    current = obj
    for part in path
        if part isa Integer
            if current isa AbstractVector || current isa JSON3.Array
                1 <= part <= length(current) || return nothing
                current = current[part]
            else
                return nothing
            end
        else
            current = _json_get(current, string(part), nothing)
            current === nothing && return nothing
        end
    end
    return current
end

function _json_string(obj, key::AbstractString)
    value = _json_get(obj, key, "")
    value === nothing && return ""
    return string(value)
end

function _json_name(obj)
    name = _json_get(obj, "name", "")
    if name isa JSON3.Object
        return _json_string(name, "en")
    end
    return string(name)
end

function _json_description(obj)
    description = _json_get(obj, "description", "")
    if description isa JSON3.Object
        return _json_string(description, "en")
    end
    return string(description)
end
