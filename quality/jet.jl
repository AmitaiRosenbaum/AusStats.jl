using AusStats
using JET
using Test

@testset "JET" begin
    @testset "Package typo analysis" begin
        # Catch undefined bindings and call targets across the package while
        # avoiding noisy inference reports from dynamic DataFrame/XLSX/JSON paths.
        JET.test_package(AusStats; target_defined_modules=true, mode=:typo)
    end

    @testset "Targeted helper calls" begin
        JET.@test_call target_modules=(AusStats,) AusStats._normalise_frequency("Daily")
        JET.@test_call target_modules=(AusStats,) AusStats._normalise_release_text("Released: April 2024")
        JET.@test_call target_modules=(AusStats,) AusStats._release_month_number("April")
        JET.@test_call target_modules=(AusStats,) AusStats._release_page_from_file_url("https://example.test/path/may-2026/file.xlsx")
        JET.@test_call target_modules=(AusStats,) AusStats._table_no_from_filename("6202.0", "https://example.test/620201.xlsx")
        JET.@test_call target_modules=(AusStats,) AusStats._release_date_from_text("Released: April 2024")
    end
end
