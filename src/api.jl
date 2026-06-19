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
    datastructure(flow_id)

Return the dimensions advertised by the ABS API datastructure for `flow_id`.
"""
function datastructure(flow_id::AbstractString)
    url = ABS_API_BASE_URL * "/datastructure/ABS/" * HTTP.escapeuri(flow_id) * "/all/latest?references=all"
    return _datastructure_dataframe(_http_json(url))
end

"""
    read_api(flow_id; key=nothing, start_period=nothing, end_period=nothing, params=NamedTuple())

Read observations from the ABS API and return a tidy `DataFrame`.
"""
function read_api(flow_id::AbstractString; key=nothing, start_period=nothing, end_period=nothing, params=NamedTuple())
    query = Dict{String,String}()
    start_period === nothing || (query["startPeriod"] = string(start_period))
    end_period === nothing || (query["endPeriod"] = string(end_period))
    for pair in pairs(params)
        query[string(first(pair))] = string(last(pair))
    end

    query_text = isempty(query) ? "" : "?" * join([HTTP.escapeuri(k) * "=" * HTTP.escapeuri(v) for (k, v) in sort(collect(query))], "&")
    api_key = key === nothing ? "all" : string(key)
    url = ABS_API_BASE_URL * "/data/ABS/" * HTTP.escapeuri(flow_id) * "/" * HTTP.escapeuri(api_key) * "/all" * query_text
    return read_api_url(url)
end

"""
    read_api_url(url)

Read an ABS API URL and return observations as a tidy `DataFrame`.
"""
function read_api_url(url::AbstractString)
    return _sdmx_data_to_dataframe(_http_json(url))
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
    dimensions = Any[]
    _collect_named_objects!(dimensions, json, ("dimensions", "Dimensions"))
    out = DataFrame(id=String[], name=String[], position=Int[])

    position = 0
    for dimension in dimensions
        if dimension isa AbstractVector
            for item in dimension
                id = _json_string(item, "id")
                isempty(id) && continue
                position += 1
                push!(out, (id, _json_name(item), position))
            end
        else
            id = _json_string(dimension, "id")
            isempty(id) && continue
            position += 1
            push!(out, (id, _json_name(dimension), position))
        end
    end

    return unique(out)
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
