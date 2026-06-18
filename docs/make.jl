using Documenter

push!(LOAD_PATH, joinpath(@__DIR__, ".."))
using AustralianStatistics

makedocs(;
    sitename="AustralianStatistics.jl",
    modules=[AustralianStatistics],
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        assets=[
            asset("assets/favicon.svg", class=:ico, islocal=true),
        ],
    ),
    pages=[
        "Home" => "index.md",
    ],
    checkdocs=:exports,
)
