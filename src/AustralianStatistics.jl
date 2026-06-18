module AustralianStatistics

using Dates
using DataFrames
using Downloads
using XLSX

export read_abs, read_abs_series, download_abs, search_abs, tidy_abs

include("download.jl")
include("parse.jl")
include("read_abs.jl")

end
