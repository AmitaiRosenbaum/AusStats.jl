@testset "Provider API" begin
    provider_rows = providers()
    @test Set(provider_rows.provider) == Set([:abs, :apra, :rba])
    @test nrow(datasets(:abs)) >= 1
    @test nrow(datafiles(:abs, "6202.0")) >= 1
    @test nrow(search_data("labour"; provider=:abs)) >= 1
    @test nrow(datasets(:rba)) >= 1
    @test nrow(search_data("cash"; provider=:rba)) >= 1
    @test_throws ArgumentError datasets(:missing)
end

@testset "RBA discovery and readers" begin
    rba_index = rba_files()
    @test "A1" in rba_index.dataset_id
    @test "cash-rate-target" in rba_index.dataset_id
    @test "balance-sheet" in rba_index.dataset_id
    @test nrow(search_rba("cash")) >= 1
    @test only(rba_files("cash-rate-target")).resource_kind == :html

    html = """
    <html><body>
      <a href="/statistics/tables/xls/b11-1-hist.xlsx">Assets & Liabilities of Australian-located Operations - B11.1</a>
      <a href="/statistics/tables/csv/b11-1-data.csv">Data</a>
      <a href="/statistics/tables/csv/f1-data.csv">F1 - Data</a>
    </body></html>
    """
    discovered = AusStats._provider_file_rows(
        AusStats._discover_rba_tables(AusStats._parse_html(html))
    )
    @test "B11.1" in discovered.dataset_id
    @test "F1" in discovered.dataset_id
    @test all(discovered.provider .== :rba)
    @test all(discovered.resource_kind .== :timeseries)

    csv_path = tempname() * ".csv"
    write(
        csv_path,
        """
        Metadata line ignored by parser
        Date,Target cash rate,Exchange rate
        2026-01-01,4.35,0.66
        2026-02-01,,0.65
        """,
    )
    tidy = read_rba(csv_path)
    @test names(tidy) == [
        "provider",
        "table_id",
        "table_title",
        "series_id",
        "series",
        "date",
        "value",
        "frequency",
        "unit",
        "source_url",
        "source_file",
    ]
    @test nrow(tidy) == 4
    @test unique(tidy.provider) == [:rba]
    @test tidy.date[1] == Date(2026, 1, 1)
    @test ismissing(tidy.value[2])

    cash_html = tempname() * ".html"
    write(
        cash_html,
        """
        <html><body>
          <h1>Cash Rate Target</h1>
          Effective Date Change% points Cash rate target %
          17 Jun 2026 0.00 4.35
          6 May 2026 +0.25 4.35
        </body></html>
        """,
    )
    cash = AusStats._read_rba_file(
        cash_html;
        metadata=(dataset_id="cash-rate-target", title="Cash Rate Target", source_url="fixture"),
    )
    @test nrow(cash) == 2
    @test cash.effective_date == [Date(2026, 6, 17), Date(2026, 5, 6)]
    @test cash.cash_rate_target == [4.35, 4.35]

    balance_html = tempname() * ".html"
    write(
        balance_html,
        """
        <html><body>
          <h1>Reserve Bank of Australia Balance Sheet</h1>
          At close of business on Wednesday, 17 June 2026
          \$ million
          Liabilities and Equity Movement Assets Movement
          Australian notes on issue 107,212 -75
          Exchange Settlement balances 172,889 6,420
          Other liabilities 16,773 1,944
          Gold and foreign exchange 113,526 2,248
          Australian dollar investments 245,457 3,087
          Other assets 2,690 -416
          The Bank's liabilities and assets data are provided on a more disaggregated basis in statistical table A1.
        </body></html>
        """,
    )
    balance = AusStats._read_rba_file(
        balance_html;
        metadata=(dataset_id="balance-sheet", title="Balance Sheet", source_url="fixture"),
    )
    @test nrow(balance) == 6
    @test unique(balance.as_at) == [Date(2026, 6, 17)]
    @test "Australian notes on issue" in balance.item
    @test "Gold and foreign exchange" in balance.item
    @test balance.value[balance.item .== "Gold and foreign exchange"] == [113526.0]
end
