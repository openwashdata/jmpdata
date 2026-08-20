# Updating the JMP data

This guide takes a fresh clone to updated data and regenerated diff
reports with an ordered set of commands. Scripts live in `data-raw/update/`; the
legacy `data-raw/gather/` scripts are the historical record and stay untouched.

Network steps (washdata.org, archive.org) must run on a local machine.
Remote sandbox sessions for this repository cannot reach either host.

## Prerequisites

R 4.1 or newer (developed on 4.6.1) and these packages:

```r
install.packages(c("tidyverse", "readxl", "openxlsx", "here", "jsonlite"))
```

`jsonlite` is only needed for the Wayback recovery step (02).

## 0. Smoke test on committed data

Both commands run offline on a fresh clone. Nothing may error, and the
regenerated outputs must leave `git status` clean.

```sh
Rscript -e 'invisible(lapply(list.files("data-raw/update", full.names=TRUE), function(f) parse(f)))'
Rscript data-raw/update/06_diff_report.R
```

The second command rebuilds `data-raw/derived_data/diff_reports/`, including
the jmp2019 vs jmp2021 raw diff, from committed snapshots only.

## 1. Optional: World Bank income groups

`04_tidy_indicators.R` writes a small teaching subset with income groups
when `data-raw/raw_data/CLASS.xlsx` exists. Download it from
<https://datacatalogfiles.worldbank.org/ddh-published/0037712/DR0090755/CLASS.xlsx>
(landing page:
<https://datahelpdesk.worldbank.org/knowledgebase/articles/906519>).
The main indicators output never depends on this file; without it the
script warns and skips only the subset.

## 2. Baselines from git history (offline)

```sh
Rscript data-raw/update/01_extract_git_history.R
```

Stages the jmp2019-era world file from commit `a04e8bb` into gitignored
`data-raw/raw_data/snapshots/jmp2019/`, writes the dated gzip copy of the
jmp2021 indicators, seeds `data-raw/derived_data/snapshots_manifest.csv` and
re-derives the jmp2019 indicators. Idempotent: a second run skips every
step.

## 3. Historic recovery (Wayback Machine, network)

```sh
Rscript data-raw/update/02_recover_archives.R
```

Recovers world files for releases washdata.org no longer serves, and
records every outcome in the manifest, including failures with their
evidence. Current known state:

- jmp2023 world file: recoverable (Wayback capture 20240520144514,
  validated max estimate year 2022).
- jmp2017: unrecoverable. No spreadsheet was archived from washdata.org
  before October 2019.
- jmp2023 raw country files: unrecoverable (0/20 archive coverage in the
  capped probe). Raw snapshots are all-or-nothing because a partial
  snapshot corrupts added/removed counts; the script never builds one.

Manual last resort: request archived world files from JMP directly. A
hand-obtained `WLD.xlsx` dropped into
`data-raw/raw_data/snapshots/<release_id>/` is picked up by the pipeline
unchanged; register it by tidying (step 5).

## 4. Download the current release (network)

```sh
Rscript data-raw/update/03_download_current.R
```

Pulls the world file and all country files (about 230) into gitignored
`data-raw/raw_data/snapshots/jmp2025/`, paced and resumable: an interrupted
run continues where it stopped. Downloads are validated (xlsx magic
bytes) and failures land in a log next to the snapshot, header-only on
success. The world file is validated (data sheets present, max estimate
year reported; 2024 is expected for the JMP 2025 release).

## 5. Tidy per release

The tidy scripts are parameterized by environment variables:

| Variable | Meaning | Default |
|---|---|---|
| `JMP_RELEASE_ID` | release being tidied | `jmp2025` |
| `JMP_SNAPSHOT_DIR` | raw input directory | `data-raw/raw_data/snapshots/<release_id>` |
| `JMP_OUTPUT_DIR` | output directory | `data-raw/derived_data` |
| `JMP_PULL_DATE` | date prefixing output files | today |
| `JMP_SOURCE` | provenance recorded in the manifest | `live` |
| `JMP_OUTPUT_COMPRESS` | write dated outputs as `.csv.gz` | `false` |

```sh
JMP_RELEASE_ID=jmp2025 Rscript data-raw/update/05_tidy_raw_data.R
JMP_RELEASE_ID=jmp2025 JMP_OUTPUT_COMPRESS=true Rscript data-raw/update/04_tidy_indicators.R
```

Use `JMP_OUTPUT_COMPRESS=true` for indicators: the dated gzip convention
keeps the committed snapshots at about 3-8 MB instead of 40 MB.

The unmatched-variables loop: new releases introduce variables the
hand-curated lookup does not know. The scripts write the unknown names to
`data-raw/derived_data/<date>_unmatched_variables.csv` and warn; when the
lookup knows less than half of a snapshot's vocabulary, `04` stops
instead. Extend `data-raw/derived_data/jmp_wash_variables_complete.csv` by
hand and re-run. Current state: the jmp2023 and jmp2025 world files use a
renamed vocabulary, so their indicator snapshots are blocked on this loop
(tracked in issue #9). The raw pipeline is not affected.

## 6. Diff report

```sh
Rscript data-raw/update/06_diff_report.R
```

Diffs every consecutive pair of available releases per pipeline and
writes per-collection-year counts, row-level detail and `diff_report.md`
to `data-raw/derived_data/diff_reports/`. Unavailable releases appear
explicitly in the snapshot inventory.

## 7. One command

`data-raw/update/run_update.R` runs steps 2 to 6 in order, with parameters at
the top of the file (which network steps to run, which releases to
tidy). Edit the parameters, then:

```sh
Rscript data-raw/update/run_update.R
```

## What to commit

Commit: dated derived files in `data-raw/derived_data/` (`*_jmp_sanitation_raw_data.csv`/`.rds`,
`*_jmp_washdata_indicators.csv.gz`, variable lists, unmatched-variable
CSVs), `snapshots_manifest.csv`, everything under
`data-raw/derived_data/diff_reports/`, and any hand-extension of
`jmp_wash_variables_complete.csv`.

Do not commit anything under `data-raw/raw_data/snapshots/` (gitignored: raw
per-release xlsx). The committed `data-raw/raw_data/WLD.xlsx` and `UGA.xlsx`
are the only surviving JMP-2021-era raw inputs and are never overwritten.
