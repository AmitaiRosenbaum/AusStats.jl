const ABS_BASE_URL = "https://www.abs.gov.au"
const ABS_API_BASE_URL = "https://data.api.abs.gov.au/rest"

const ABS_USER_AGENT = "AustralianStatistics.jl/0.2"

struct ABSError <: Exception
    message::String
end

Base.showerror(io::IO, error::ABSError) = print(io, error.message)

function _http_get(url::AbstractString; accept::AbstractString="*/*")
    response = HTTP.get(url, ["User-Agent" => ABS_USER_AGENT, "Accept" => accept])
    status = response.status
    200 <= status < 300 || throw(ABSError("ABS request failed with HTTP $status: $url"))
    return response
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
