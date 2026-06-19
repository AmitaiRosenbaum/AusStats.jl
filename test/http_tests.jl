@testset "HTTP wrappers" begin
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
    finally
        close(server)
    end
end
