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
        sheet["A4"] = "Frequency"
        sheet["B4"] = "Monthly"
        sheet["A5"] = "Series Type"
        sheet["B5"] = "Seasonally adjusted"
        sheet["A6"] = "Data Type"
        sheet["B6"] = "Stock"
        sheet["A7"] = "Apr-26"
        sheet["B7"] = 12.5
        sheet["A8"] = "May-26"
        sheet["B8"] = "not numeric"

        sheet = XLSX.addsheet!(xf, "Table 2")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "B1234567"
        sheet["A2"] = "Apr-26"
        sheet["B2"] = 99.0

        sheet = XLSX.addsheet!(xf, "Data10")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "C1234567"
        sheet["A2"] = "Apr-26"
        sheet["B2"] = 101.0
    end

    return path
end

function period_workbook()
    path = tempname() * ".xlsx"

    XLSX.openxlsx(path, mode="w") do xf
        sheet = xf[1]
        XLSX.rename!(sheet, "Monthly")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "M1234567"
        sheet["A2"] = "Jan-2024"
        sheet["B2"] = 1
        sheet["A3"] = "2024-02"
        sheet["B3"] = 2

        sheet = XLSX.addsheet!(xf, "Quarterly")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "Q1234567"
        sheet["A2"] = "Mar-2024"
        sheet["B2"] = 3
        sheet["A3"] = "2024-Q2"
        sheet["B3"] = 4
        sheet["A4"] = "Q3 2024"
        sheet["B4"] = 5

        sheet = XLSX.addsheet!(xf, "Annual")
        sheet["A1"] = "Series ID"
        sheet["B1"] = "Y1234567"
        sheet["A2"] = "2024"
        sheet["B2"] = 6
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
    @test names(tidy) == ["table", "date", "series_id", "value", "unit", "series_type", "data_type", "frequency", "series"]
    @test tidy.date[1] == Date(2026, 4, 1)
    @test tidy.date[2] == Date(2026, 5, 1)
    @test tidy.value[1] == 12.5
    @test ismissing(tidy.value[2])
    @test tidy.frequency[1] == "monthly"
    @test tidy.series[1] == "Employed total"
    @test tidy.unit[1] == "Persons"
    @test tidy.series_type[1] == "Seasonally adjusted"
    @test tidy.data_type[1] == "Stock"

    periods = tidy_abs(period_workbook())
    @test periods[periods.series_id .== "M1234567", :date] == [Date(2024, 1, 1), Date(2024, 2, 1)]
    @test unique(periods[periods.series_id .== "M1234567", :frequency]) == ["monthly"]
    @test periods[periods.series_id .== "Q1234567", :date] == [Date(2024, 1, 1), Date(2024, 4, 1), Date(2024, 7, 1)]
    @test unique(periods[periods.series_id .== "Q1234567", :frequency]) == ["quarterly"]
    @test periods[periods.series_id .== "Y1234567", :date] == [Date(2024, 1, 1)]
    @test periods[periods.series_id .== "Y1234567", :frequency] == ["annual"]

    raw = read_abs(workbook)
    @test raw isa DataFrame

    sample_workbook(joinpath(default_cache_dir(), source.filename))
    @test first(read_abs("6202.0"; tables=["1"]).table) == "Data1"
    @test unique(read_abs("6202.0"; tables=["1"]).table) == ["Data1"]
    @test first(read_abs("6202.0"; tables=["Table 1"]).table) == "Data1"
    @test first(read_abs("6202.0"; tables=["Data1"]).table) == "Data1"
    @test first(read_abs("6202.0"; tables=1).table) == "Data1"
    @test_throws ArgumentError read_abs("6202.0"; tables=1, header_row=1)

    series = read_abs_series("A84423043A"; cat_no="6202.0")
    @test first(series.series_type) == "Seasonally adjusted"
    @test first(series.data_type) == "Stock"
end
