const ABS_BASE_URL = "https://www.abs.gov.au"
const ABS_API_BASE_URL = "https://data.api.abs.gov.au/rest"

function _package_version()
    project = joinpath(dirname(@__DIR__), "Project.toml")
    if isfile(project)
        parsed = Pkg.TOML.parsefile(project)
        return string(get(parsed, "version", "dev"))
    end
    return "dev"
end

const ABS_USER_AGENT = string("AustralianStatistics.jl/", _package_version())

struct ABSError <: Exception
    message::String
end

Base.showerror(io::IO, error::ABSError) = print(io, error.message)

function _http_get(url::AbstractString; accept::AbstractString="*/*", readtimeout::Real=60)
    headers = ["User-Agent" => ABS_USER_AGENT, "Accept" => accept]
    response = HTTP.get(url, headers; readtimeout=readtimeout, status_exception=false)
    status = response.status
    if !(200 <= status < 300)
        guidance = _large_api_query_guidance(status)
        message = string("ABS request failed with HTTP ", status, ": ", url, guidance)
        throw(ABSError(message))
    end
    return response
end

function _large_api_query_guidance(status::Integer)
    if status in (400, 413, 414, 429, 500, 502, 503, 504)
        return ". Large ABS API queries may fail; narrow the request with `filters`, `start_period`, or `end_period`."
    end
    return ""
end

function _http_text(url::AbstractString)
    return String(_http_get(url; accept="text/html,application/json,*/*").body)
end

function _http_json(url::AbstractString)
    return JSON3.read(String(_http_get(url; accept="application/json,*/*").body))
end

function _absolute_url(url::AbstractString; base::AbstractString=ABS_BASE_URL)
    text = strip(url)
    startswith(lowercase(text), "http://") && return text
    startswith(lowercase(text), "https://") && return text
    if startswith(text, "//")
        return "https:" * text
    elseif startswith(text, "/")
        return base * text
    end
    return rstrip(base, '/') * "/" * text
end

function _safe_filename(value::AbstractString)
    name = replace(strip(value), r"[^\w.\-]+" => "_")
    name = replace(name, r"_+" => "_")
    name = strip(name, '_')
    return isempty(name) ? "download" : name
end

function _url_filename(url::AbstractString)
    clean = split(url, '?'; limit=2)[1]
    name = basename(clean)
    return isempty(name) ? "download" : _safe_filename(name)
end
