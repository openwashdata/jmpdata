# jmpdata 0.2.0

## Breaking change: values of `residence` in `jmpraw`

- The `residence` column of `jmpraw` is corrected and now changes
  value for 4,805 of 26,926 rows (17.8 percent). It is derived from the
  suffix of `var_short` (`_t` or `_n` national, `_r` rural, `_u`
  urban). Before, `_n`, `_r` and `_u` were matched anywhere in the
  code, so a code such as `s_lat_nemp_u` was labelled national and
  `s_sew_rtp_t` rural (#23).
- Changed rows, old value to new value: national to rural 2,086;
  national to urban 2,108; rural to national 595; rural to urban 16.
  The other 22,120 rows are unchanged. Affected are all open
  defecation (`s_ns_*`), all not emptied (`*_nemp_*`), and the sewer
  transport and containment variables.
- The new column `residence_legacy` keeps the old values, so earlier
  results can be reproduced and compared. Do not use it for analysis.
- The derivation lives in `derive_residence()` in
  `data-raw/update/00_functions.R` and is used by
  `data-raw/update/05_tidy_raw_data.R`. `jmpindicators` was already
  correct and is unchanged.
- `inst/extdata/jmpraw.csv` and `jmpraw.xlsx` include both columns.

# jmpdata 0.1.0

First release of jmpdata as an openwashdata R data package,
converted from the former scripts-and-outputs repository jmpinput
and renamed, since the package now covers both the input data and
the modelled estimates.

- `jmpraw`: survey-level input data on sanitation underlying the
  WHO/UNICEF JMP estimates (26,926 data points, JMP 2025 release,
  pulled 2026-08-20).
- `jmpindicators`: modelled JMP indicator estimates for drinking
  water, sanitation and hygiene (424,575 estimates, JMP 2025
  release), with variable codes normalized to the legacy JMP
  vocabulary.
- Both datasets are documented from `data-raw/dictionary.csv` and
  downloadable from `inst/extdata/` (csv and xlsx for `jmpraw`,
  gzip csv for `jmpindicators`).
- The update pipeline, raw inputs, dated snapshots and diff reports
  live under `data-raw/`; see `data-raw/UPDATING.md`.
- License changed from MIT to CC BY 4.0.
