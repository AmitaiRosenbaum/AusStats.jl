module AustralianStatistics

using Dates
using DataFrames
using Downloads
using Cascadia
using Gumbo
using HTTP
using JSON3
using Preferences
using Scratch
using XLSX

export read_abs, read_abs_url, read_abs_local, read_metadata, tidy_abs
export read_series, separate_series, latest_date
export download_abs, download_cube, read_cube, search_cubes
export search_abs, catalogues, files, releases, refresh_abs!
export dataflows, datastructure, read_api, read_api_url
export default_cache_dir, cache_info, clear_cache!

include("cache.jl")
include("http.jl")
include("download.jl")
include("parse.jl")
include("read_abs.jl")
include("cube.jl")
include("api.jl")

end
