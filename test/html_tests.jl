@testset "ABS HTML fixtures" begin
    discovered = discovery_fixture_rows()
    @test nrow(discovered) == 3
    @test "1" in discovered.table_no
    @test "2" in discovered.table_no
    @test all(startswith.(discovered.url, "https://www.abs.gov.au/"))
    @test all(discovered.file_type .== "xlsx")
    @test "Download xlsx [750.18 KB]" ∉ discovered.file_title
    @test only(discovered[discovered.is_cube, :file_title]) == "Labour Force, Australia, detailed, quarterly, data cube"

    archive_releases = archive_fixture_releases()
    @test archive_releases.release_date == [Date(2019, 9, 1), Date(2019, 12, 1), Date(2020, 3, 1)]
    @test all(startswith.(archive_releases.release_url, "https://www.abs.gov.au/"))

    historical_files = historical_release_fixture_rows()
    @test nrow(historical_files) == 2
    @test historical_files.release_date == fill("sep-2019", 2)
    @test Set(historical_files.table_no) == Set(["1", "2b"])
end

