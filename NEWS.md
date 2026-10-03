# jmpdata 0.1.1

- `jmpraw` gains a new column `residence_std` with the residence level
  derived from the suffix of `var_short` (`_t` or `_n` national, `_r`
  rural, `_u` urban). The legacy `residence` column matched `_n`, `_r`
  and `_u` anywhere in the code, so 4,805 of 26,926 rows had the wrong
  level (for example `s_lat_nemp_u` was labelled national and
  `s_sew_rtp_t` rural). Use `residence_std` for any urban and rural
  analysis (#23).
- The legacy `residence` column is unchanged, so earlier results and
  the pipeline diff reports stay comparable.
- The derivation lives in `derive_residence()` in
  `data-raw/update/00_functions.R` and is used by
  `data-raw/update/05_tidy_raw_data.R`.
- `inst/extdata/jmpraw.csv` and `jmpraw.xlsx` include the new column.

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
