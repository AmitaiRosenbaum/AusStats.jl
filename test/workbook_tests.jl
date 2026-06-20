@testset "Workbook parsing fixtures" begin
    workbook = sample_workbook()
    tidy = tidy_abs(workbook; cat_no="6202.0", release_date="apr-2026")
    @test nrow(tidy) == 6
    @test Set(tidy.series_id) == Set(["A84423043A", "B84423043B", "C1234567", "D1234567"])
    @test nrow(tidy[tidy.table .== "Data1", :]) == 4
    @test nrow(tidy[tidy.table .== "Table 2", :]) == 1
    @test nrow(tidy[tidy.table .== "Data10", :]) == 1
    @test "Notes" ∉ tidy.table

    periods = tidy_abs(period_workbook())
    @test periods[periods.series_id .== "M1234567", :date] == [Date(2024, 1, 1), Date(2024, 2, 1)]
    @test periods[periods.series_id .== "Q1234567", :date] == [Date(2024, 1, 1), Date(2024, 4, 1), Date(2024, 7, 1)]
    @test periods[periods.series_id .== "Y1234567", :date] == [Date(2024, 1, 1)]

    metadata = read_metadata(metadata_layout_workbook())
    @test Set(metadata.cat_no) == Set(["6401.0", "5206.0", "6302.0", "6160.0.55.001"])
    @test Set(metadata.frequency) == Set(["quarterly", "semiannual", "weekly"])
end

@testset "Workbook parser helper edge cases" begin
    workbook = sample_workbook()
    XLSX.openxlsx(workbook) do xf
        @test AusStats._selected_sheets(xf, nothing) == XLSX.sheetnames(xf)
        @test AusStats._selected_sheets(xf, "Data1") == ["Data1"]
        @test AusStats._selected_sheets(xf, ("Data1", "Table 2")) == ["Data1", "Table 2"]
        raw = AusStats._read_sheet(xf["Data1"]; header_row=1)
        @test nrow(raw) >= 1
        @test "Series_ID" in names(raw)
    end
    @test AusStats._column_names(Any[missing, "", "A B", "A B"]) == [:Column1, :Column2, :A_B, :A_B_2]

    no_metadata_path = tempname() * ".xlsx"
    XLSX.openxlsx(no_metadata_path, mode="w") do xf
        sheet = xf[1]
        XLSX.rename!(sheet, "No metadata")
        sheet["A1"] = "Notes"
        sheet["B1"] = "Only notes"
    end
    XLSX.openxlsx(no_metadata_path) do xf
        @test isempty(AusStats._metadata_sheet(xf["No metadata"], "No metadata"))
    end

    rows = Any[
        Any["Header", "Value"],
        Any["Notes", "not a date"],
        Any["Jan-2024", 1],
        Any["Feb-2024", 2],
    ]
    best_col, date_rows = AusStats._best_date_column(rows)
    @test best_col == 1
    @test date_rows == [3, 4]

    fallback_rows = Any[
        Any["A1234567X", "Description"],
        Any["2024", 10],
    ]
    @test AusStats._series_id_for_column(fallback_rows, 1, 2, Dict{String,Int}()) == "A1234567X"
    @test AusStats._series_id_for_column(fallback_rows, 2, 2, Dict{String,Int}()) == "Column 2"
    @test AusStats._series_id_for_row(Any[]) == ""
    @test AusStats._series_id_for_row(Any["Plain series", 10]) == "Plain series"
    @test AusStats._series_name_for_row(Any["Plain series", 10], Any["Name", "Value"]) == "Plain series"
    @test ismissing(AusStats._series_name_for_row(Any["A1234567X", Date(2024, 1, 1), 10], Any["ID", "Date", "Value"]))

    @test AusStats._parse_abs_date(DateTime(2024, 5, 2, 3, 4)) == Date(2024, 5, 2)
    @test AusStats._parse_abs_date(45292) == Date(2024, 1, 1)
    @test AusStats._parse_abs_date(42) === nothing
    @test AusStats._parse_abs_date("2024/13") === nothing
    @test AusStats._parse_abs_date("") === nothing
    @test AusStats._period_start("2024-Q4", "annual") == Date(2024, 1, 1)
    @test AusStats._infer_frequency([Date(2024, 1, 1)]) == "unknown"
    @test AusStats._infer_frequency([Date(2024, 1, 1), Date(2024, 2, 1)]) == "monthly"
    @test AusStats._infer_frequency([Date(2024, 1, 1), Date(2024, 4, 1)]) == "quarterly"
    @test AusStats._infer_frequency([Date(2024, 1, 1), Date(2025, 1, 1)]) == "annual"
    @test AusStats._infer_frequency([Date(2024, 1, 1), Date(2024, 6, 1)]) == "unknown"
    @test AusStats._month_delta(Date(2024, 1, 1), Date(2025, 3, 1)) == 14

    @test AusStats._normalise_frequency("Yearly") == "annual"
    @test AusStats._normalise_frequency("Fortnightly") == "fortnightly"
    @test AusStats._normalise_frequency("Daily") == "daily"
    @test AusStats._normalise_frequency("Mystery cadence") == "unknown"
    @test AusStats._normalise_frequency("") == "unknown"
    @test !AusStats._looks_like_abs_series_id("")
    @test AusStats._sheet_context("Table 9", 3, missing, missing).table_no == "9"
    @test AusStats._looks_like_table_title("Table 12. Detailed estimates")
    @test !AusStats._looks_like_table_title("Series ID")
    @test AusStats._table_title_score("Tables 2b to 9b. All quarterly series") > AusStats._table_title_score("Short")

    metadata_rows = Any[
        Any["Catalogue Number", "9999.0"],
        Any["Released: March 2024"],
        Any["Table 5. Example table"],
        Any["2024", 1],
    ]
    context = AusStats._sheet_context(metadata_rows, "Fallback", 1, missing, missing)
    @test context.cat_no == "9999.0"
    @test context.release_date == "mar-2024"
    @test context.table_no == "5"
    @test AusStats._infer_release_value(Any[Any["Release Date", ""], Any["Released: April 2024"]]) == "apr-2024"
    @test isempty(AusStats._tidy_sheet_time_across(Any[Any["No dates"], Any["Still no dates"]], "NoDates"))
    @test AusStats._first_matching_text(Any["none", "Catalogue 1234.5"], r"[0-9]{4}\.[0-9]") == "1234.5"
    @test AusStats._first_matching_text(Any["none"], r"[0-9]+") === nothing
end
