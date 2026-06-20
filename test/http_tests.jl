@testset "HTTP wrappers" begin
    workbook = sample_workbook()
    cube = cube_workbook()
    server = HTTP.serve!(listenany=true) do request
        target = string(request.target)
        if startswith(target, "/json")
            return HTTP.Response(200, ["Content-Type" => "application/json"], body="""{"ok":true}""")
        elseif startswith(target, "/api")
            return HTTP.Response(200, ["Content-Type" => "application/json"], body="""
            {
              "structure": {
                "dimensions": {
                  "series": [{"id": "DIM", "values": [{"id": "A"}]}],
                  "observation": [{"id": "TIME_PERIOD", "values": [{"id": "2024-Q1"}]}]
                }
              },
              "dataSets": [{"series": {"0": {"observations": {"0": [7]}}}}]
            }
            """)
        elseif startswith(target, "/large")
            return HTTP.Response(413, "too large")
        elseif startswith(target, "/missing")
            return HTTP.Response(404, "missing")
        elseif startswith(target, "/bad-json")
            return HTTP.Response(200, ["Content-Type" => "application/json"], body="{")
        elseif startswith(target, "/jul-2026/workbook.xlsx")
            return HTTP.Response(200, ["Content-Type" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"], body=read(workbook))
        elseif startswith(target, "/jul-2026/cube.xlsx")
            return HTTP.Response(200, ["Content-Type" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"], body=read(cube))
        end
        return HTTP.Response(200, "hello")
    end

    try
        base = "http://127.0.0.1:$(HTTP.port(server))"
        response = AusStats._http_get(base * "/text")
        @test response.status == 200
        @test String(response.body) == "hello"
        @test AusStats._http_text(base * "/text") == "hello"
        @test AusStats._http_json(base * "/json").ok == true

        missing_message = try
            AusStats._http_get(base * "/missing")
            ""
        catch error
            sprint(showerror, error)
        end
        @test occursin("HTTP 404", missing_message)
        @test !occursin("Large ABS API queries", missing_message)

        large_message = try
            AusStats._http_get(base * "/large")
            ""
        catch error
            sprint(showerror, error)
        end
        @test occursin("HTTP 413", large_message)
        @test occursin("Large ABS API queries", large_message)

        api_rows = read_api_url(base * "/api")
        @test nrow(api_rows) == 1
        @test api_rows.value == [7.0]

        wrapped_message = try
            read_api_url(base * "/large")
            ""
        catch error
            sprint(showerror, error)
        end
        @test occursin("Narrow large ABS API queries", wrapped_message)

        @test_throws Exception read_api_url(base * "/bad-json")

        workbook_url = base * "/jul-2026/workbook.xlsx"
        @test nrow(read_abs_url(workbook_url; tables=1, cache=false)) == 4
        @test nrow(read_abs(workbook_url; tables=1, cache=false)) == 4
        metadata = read_metadata(workbook_url; tables=1)
        @test nrow(metadata) == 2
        @test all(metadata.release_date .== "jul-2026")

        cube_url = base * "/jul-2026/cube.xlsx"
        cube_rows = read_cube(cube_url; cache=false, family=:generic)
        @test nrow(cube_rows) == 2
        @test all(isfile, cube_rows.source_file)
    finally
        close(server)
    end
end
