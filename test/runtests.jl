using AustralianStatistics
using DataFrames
using Dates
using Test
using XLSX

function sample_workbook(path=tempname() * ".xlsx")

    XLSX.openxlsx(path, mode="w") do xf
        sheet = xf[1]
        XLSX.rename!(sheet, "Data1")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "A84423043A"
        sheet["A2"] = "Data item"
        sheet["B2"] = "Employed total"
        sheet["A3"] = "Unit"
        sheet["B3"] = "Persons"
        sheet["A4"] = "Apr-26"
        sheet["B4"] = 12.5
        sheet["A5"] = "May-26"
        sheet["B5"] = ""

        sheet = XLSX.addsheet!(xf, "Table 2")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "B1234567"
        sheet["A2"] = "Apr-26"
        sheet["B2"] = 99.0
    end

    return path
end

@testset "AustralianStatistics smoke tests" begin
    labour = search_abs("labour")
    @test "6202.0" in labour.cat_no

    cpi = search_abs("cpi")
    @test "6401.0" in cpi.cat_no

    cache_dir = mktempdir()
    source = AustralianStatistics.ABS_TIME_SERIES_WORKBOOKS["6202.0"]
    cached_path = joinpath(cache_dir, source.filename)
    touch(cached_path)
    @test download_abs("6202.0"; dest=cache_dir) == cached_path
    @test isfile(cached_path)

    workbook = sample_workbook()

    tidy = tidy_abs(workbook)
    @test tidy isa DataFrame
    @test names(tidy) == ["series_id", "table", "date", "value", "unit", "series", "frequency"]
    @test tidy.date[1] == Date(2026, 4, 1)

    raw = read_abs(workbook)
    @test raw isa DataFrame

    sample_workbook(joinpath(default_cache_dir(), source.filename))
    @test first(read_abs("6202.0"; tables=["1"]).table) == "Data1"
    @test first(read_abs("6202.0"; tables=["Table 1"]).table) == "Data1"
    @test first(read_abs("6202.0"; tables=["Data1"]).table) == "Data1"
    @test first(read_abs("6202.0"; tables=1).table) == "Data1"
end
