function _online_tests_enabled()
    return lowercase(get(ENV, "AusStats_ONLINE_TESTS", "false")) in ("1", "true", "yes")
end

if _online_tests_enabled()
    @testset "Online latest release" begin
        refreshed = refresh_abs!()
        @test nrow(refreshed) >= 1
        downloaded = download_abs("6202.0"; force=true)
        @test isfile(downloaded)
        latest = read_abs("6202.0"; tables=1, refresh=true)
        @test latest isa DataFrame
        @test nrow(latest) > 0
        @test all(name -> name in names(latest), ["date", "series_id", "value", "table"])
        @test latest_date(latest) !== missing
    end

    @testset "Online historical release" begin
        files_2019 = AusStats._files_for_release(
            "6345.0", Date(2019, 9, 1); refresh=true, strict=true
        )
        @test nrow(files_2019) >= 1
        @test all(files_2019.release_date .== "sep-2019")
        timeseries_2019 = files_2019[files_2019.is_timeseries, :]
        @test nrow(timeseries_2019) >= 1
        selected = first(sort(timeseries_2019, [:table_no, :filename]))
        wpi = download_abs(
            "6345.0"; file=selected.filename, release=Date(2019, 9, 1), force=true
        )
        @test isfile(wpi)
    end
else
    @info "Skipping online tests; set AusStats_ONLINE_TESTS=true to enable latest and historical release checks."
end
