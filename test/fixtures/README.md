# Test Fixtures

These fixtures keep the default test suite deterministic and offline.

- `abs_publication_downloads.html` is a saved ABS-style publication downloads page used to test catalogue and cube file discovery.
- `abs_archive_releases.html` is a saved archive listing used to test historical release discovery.
- `abs_wpi_sep_2019_downloads.html` is a saved historical Wage Price Index release page used to test release-file parsing.

Workbook, cube, metadata, and API response fixtures are generated synthetically in `test/runtests.jl` so the tests can cover parser edge cases without storing large ABS spreadsheets in the repository.

Online tests are gated behind:

```sh
AUSTRALIANSTATISTICS_ONLINE_TESTS=true
```

The online suite is intentionally small and avoids brittle assertions about exact latest values.
