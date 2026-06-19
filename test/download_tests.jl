@testset "Download and discovery edge cases" begin
    seed = AusStats._seed_for_catalogue("6202.0")
    html = """
    <html>
      <head><meta name="description" content="Fixture description"></head>
      <body>
        <h1>Fixture Labour Force</h1>
        <a href="/statistics/labour/employment-and-unemployment/labour-force-australia/archive">Past releases</a>
        <a href="/statistics/labour/employment-and-unemployment/labour-force-australia/may-2026">Labour Force, Australia May 2026</a>
        <section class="downloads">
          <p>Table 3. Detailed labour force data <a href="/statistics/labour/employment-and-unemployment/labour-force-australia/may-2026/62020003.xlsx?download=1#file">Download xlsx [12 KB]</a></p>
          <p>Payroll data cube <a href="//www.abs.gov.au/statistics/labour/employment-and-unemployment/labour-force-australia/may-2026/cube.csv">csv</a></p>
        </section>
      </body>
    </html>
    """
    doc = AusStats._parse_html(html)
    rows = AusStats._file_rows_dataframe(AusStats._discover_files_from_doc(
        doc,
        seed;
        title="Fixture Labour Force",
        description="Fixture description",
        page_url="https://www.abs.gov.au/statistics/labour/employment-and-unemployment/labour-force-australia/may-2026",
    ))
    @test nrow(rows) == 2
    @test "3" in rows.table_no
    @test "may-2026" in rows.release_date
    @test any(rows.is_cube)
    table3 = rows[rows.table_no .== "3", :]
    @test nrow(table3) == 1
    @test only(table3.table_title) == "Table 3. Detailed labour force data"
    @test only(rows[rows.is_cube, :table_no]) == ""
    @test AusStats._archive_links(doc, seed) == ["https://www.abs.gov.au/statistics/labour/employment-and-unemployment/labour-force-australia/archive"]
    @test AusStats._release_links(doc, seed) == ["https://www.abs.gov.au/statistics/labour/employment-and-unemployment/labour-force-australia/may-2026"]

    @test AusStats._absolute_url(" HTTP://example.test/file.xlsx ") == "HTTP://example.test/file.xlsx"
    @test AusStats._absolute_url("//example.test/file.xlsx") == "https://example.test/file.xlsx"
    @test AusStats._absolute_url("relative/file.xlsx"; base="https://example.test/base/") == "https://example.test/base/relative/file.xlsx"
    @test AusStats._safe_filename(" ?? ") == "download"
    @test AusStats._url_filename("https://example.test/") == "download"
    @test AusStats._file_type("https://example.test/download", "Detailed data cube") == "cube"
    @test AusStats._file_type("https://example.test/download", "Plain file") == "unknown"
    @test AusStats._release_date_from_text("Released 2026 September") == Date(2026, 9, 1)
    @test AusStats._release_date_from_text("not a release") === nothing
    @test AusStats._large_api_query_guidance(413) != ""
    @test AusStats._large_api_query_guidance(404) == ""

    legacy_rows = [Dict(
        "cat_no" => "9999.0",
        "title" => "Legacy",
        "description" => "Legacy description",
        "page_url" => "https://example.test/legacy",
        "release_date" => "jan-2026",
        "file_title" => "Table 7. Legacy table",
        "url" => "https://example.test/legacy.xlsx",
        "filename" => "legacy.xlsx",
        "file_type" => "xlsx",
        "table_no" => "7",
        "is_timeseries" => true,
        "is_cube" => false,
    )]
    mkpath(dirname(AusStats._index_path()))
    open(AusStats._index_path(), "w") do io
        JSON3.write(io, legacy_rows)
    end
    legacy_index = AusStats._read_index()
    @test legacy_index.table_title == ["Table 7. Legacy table"]
    AusStats._write_index(AusStats._file_rows_dataframe(AusStats._seed_file_rows()))

    releases_df = AusStats._release_rows_dataframe([
        AusStats._release_row(cat_no="9999.0", title="Bad", release_date=Date(2026, 2, 1), release_url="https://example.test/bad"),
    ])
    AusStats._write_release_index("9999.0", releases_df)
    @test AusStats._read_release_index("9999.0").release_date == [Date(2026, 2, 1)]
    write(AusStats._release_index_path("9999.0"), """[{"cat_no":"9999.0","title":"Bad date","release_date":"feb-2026","release_url":"https://example.test/bad"}]""")
    @test nrow(AusStats._read_release_index("9999.0")) == 0

    @test_throws ArgumentError AusStats._select_file("6202.0"; file="definitely missing", cube=false)
    @test_throws ArgumentError AusStats._select_file("6202.0"; release="definitely missing", cube=false)
    @test_throws ArgumentError AusStats._select_file("6401.0"; cube=true)
    @test nrow(AusStats._files_for_release("6202.0", Date(1901, 1, 1); strict=false)) == 0
end

@testset "Discovery helper edge cases" begin
    seed = AusStats._seed_for_catalogue("6202.0")
    @test_throws ArgumentError AusStats._seed_for_catalogue("0000.0")
    @test AusStats._release_key(Date(2026, 12, 1)) == "dec-2026"
    @test AusStats._release_month_number("September") == 9
    @test AusStats._release_page_from_file_url("https://example.test/path/file.xlsx") == "https://example.test/path"
    @test AusStats._release_page_from_file_url("https://example.test/path/may-2026/file.xlsx") == "https://example.test/path/may-2026"
    @test AusStats._looks_like_release_url(seed.page_url * "/may-2026", seed)
    @test !AusStats._looks_like_release_url("https://example.test/may-2026", seed)
    @test occursin("no releases are known", AusStats._missing_release_message("9999.0", Date(2026, 1, 1), Date[]))
    @test occursin("2026-02-01", AusStats._missing_release_message("9999.0", Date(2026, 1, 15), [Date(2026, 2, 1), Date(2027, 1, 1)]))

    generic_html = """
    <html><body>
      <p><a href="/files/62020004.xlsx">Download</a></p>
      <p>Table 8. Label from context <a href="/files/context.xlsx">xlsx</a></p>
      <p><a href="/files/data-cube.xlsx">Download xlsx</a></p>
    </body></html>
    """
    doc = AusStats._parse_html(generic_html)
    rows = AusStats._file_rows_dataframe(AusStats._discover_files_from_doc(
        doc,
        seed;
        title=seed.title,
        description=seed.description,
        page_url=seed.page_url * "/jun-2026",
    ))
    @test nrow(rows) == 3
    @test "4" in rows.table_no
    @test "8" in rows.table_no
    @test any(rows.is_cube)
    @test any(occursin.("context", lowercase.(rows.file_title)))

    first_row = AusStats._file_row(;
        cat_no="1",
        title="A",
        description="",
        page_url="",
        release_date="jan-2026",
        file_title="Download",
        url="https://example.test/a.xlsx",
        filename="a.xlsx",
        file_type="xlsx",
        table_no="",
        table_title="Download",
        is_timeseries=true,
        is_cube=false,
    )
    better_row = AusStats._file_row(;
        cat_no="1",
        title="A",
        description="",
        page_url="",
        release_date="jan-2026",
        file_title="Table 2. Better title",
        url="https://example.test/a.xlsx",
        filename="a.xlsx",
        file_type="xlsx",
        table_no="2",
        table_title="Table 2. Better title",
        is_timeseries=true,
        is_cube=false,
    )
    @test AusStats._better_file_row(nothing, first_row) == first_row
    @test AusStats._better_file_row(first_row, better_row) == better_row
    @test AusStats._context_score("Table 1. Short") > AusStats._context_score("Download")
    @test AusStats._title_score("Table 1. Good") > AusStats._title_score("Download")
end

@testset "Local discovery flows" begin
    base_ref = Ref("")
    server = HTTP.serve!(listenany=true) do request
        target = string(request.target)
        if target == "/direct"
            return HTTP.Response(200, body="""
            <html>
              <head><meta name="description" content="Direct local description"></head>
              <body>
                <h1>Direct Local Catalogue</h1>
                <p>Table 1. Direct download <a href="/direct/aug-2026/direct.xlsx">Download xlsx</a></p>
              </body>
            </html>
            """)
        elseif target == "/landing"
            return HTTP.Response(200, body="""
            <html><body>
              <h1>Fallback Local Catalogue</h1>
              <a href="$(base_ref[])/landing/aug-2026">Fallback Local Catalogue August 2026</a>
            </body></html>
            """)
        elseif target == "/landing/aug-2026"
            return HTTP.Response(200, body="""
            <html><body>
              <p>Table 2. Release page download <a href="/landing/aug-2026/release.xlsx">xlsx</a></p>
            </body></html>
            """)
        elseif target == "/release-file-page"
            return HTTP.Response(200, body="""
            <html><body>
              <p>Table 4. Release index download <a href="/release-file-page/sep-2026/release.xlsx">Download xlsx</a></p>
            </body></html>
            """)
        elseif target == "/broken"
            return HTTP.Response(500, "broken")
        end
        return HTTP.Response(404, "missing")
    end

    try
        base = "http://127.0.0.1:$(HTTP.port(server))"
        base_ref[] = base
        direct_seed = (
            cat_no = "9999.0",
            title = "Direct Local Catalogue",
            description = "Seed description",
            page_url = base * "/direct",
            file_title = "Seed file",
            url = base * "/direct/aug-2026/seed.xlsx",
            filename = "seed.xlsx",
            table_no = "1",
            is_timeseries = true,
            is_cube = false,
        )
        direct_rows = AusStats._discover_seed_files(direct_seed)
        @test length(direct_rows) == 1
        @test only(direct_rows).title == "Direct Local Catalogue"
        @test only(direct_rows).description == "Direct local description"
        @test only(direct_rows).release_date == "aug-2026"

        fallback_seed = (
            cat_no = "9998.0",
            title = "Fallback Local Catalogue",
            description = "Seed description",
            page_url = base * "/landing",
            file_title = "Seed file",
            url = base * "/landing/aug-2026/seed.xlsx",
            filename = "seed.xlsx",
            table_no = "1",
            is_timeseries = true,
            is_cube = false,
        )
        fallback_rows = AusStats._discover_seed_files(fallback_seed)
        @test length(fallback_rows) == 1
        @test only(fallback_rows).table_no == "2"

        broken_seed = (
            cat_no = "9997.0",
            title = "Broken Local Catalogue",
            description = "Seed description",
            page_url = base * "/broken",
            file_title = "Seed file",
            url = base * "/broken/oct-2026/seed.xlsx",
            filename = "seed.xlsx",
            table_no = "1",
            is_timeseries = true,
            is_cube = false,
        )
        @test only(AusStats._discover_seed_files(broken_seed)).filename == "seed.xlsx"

        release_rows = AusStats._release_rows_dataframe([
            AusStats._release_row(cat_no="6202.0", title="", release_date=Date(2026, 9, 1), release_url=base * "/release-file-page"),
        ])
        AusStats._write_release_index("6202.0", release_rows)
        release_cache_path = AusStats._release_file_index_path("6202.0", Date(2026, 9, 1))
        isfile(release_cache_path) && rm(release_cache_path)
        release_files = AusStats._files_for_release("6202.0", Date(2026, 9, 1); refresh=false, strict=true)
        @test nrow(release_files) == 1
        @test release_files.table_no == ["4"]
        @test isfile(release_cache_path)

        no_html_rows = AusStats._release_rows_dataframe([
            AusStats._release_row(cat_no="6202.0", title="No HTML", release_date=Date(2026, 10, 1), release_url=base * "/broken"),
        ])
        AusStats._write_release_index("6202.0", no_html_rows)
        @test nrow(AusStats._files_for_release("6202.0", Date(2026, 10, 1); refresh=false, strict=false)) == 0
    finally
        close(server)
    end
end
