# Changelog

## jmpinput 0.1.0

First release of jmpinput as an openwashdata R data package, converted
from the former scripts-and-outputs repository.

- `jmpraw`: survey-level input data on sanitation underlying the
  WHO/UNICEF JMP estimates (26,926 data points, JMP 2025 release, pulled
  2026-08-20).
- `jmpindicators`: modelled JMP indicator estimates for drinking water,
  sanitation and hygiene (424,575 estimates, JMP 2025 release), with
  variable codes normalized to the legacy JMP vocabulary.
- Both datasets are documented from `data-raw/dictionary.csv` and
  downloadable from `inst/extdata/` (csv and xlsx for `jmpraw`, gzip csv
  for `jmpindicators`).
- The update pipeline, raw inputs, dated snapshots and diff reports live
  under `data-raw/`; see `data-raw/UPDATING.md`.
- License changed from MIT to CC BY 4.0.
