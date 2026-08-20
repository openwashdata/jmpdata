# JMP snapshot diff report

Generated on 2026-08-20 by `R/update/06_diff_report.R` ([issue #5](https://github.com/openwashdata/jmpinput/issues/5)). All numbers come from committed snapshots; no network access is used. The CSV files next to this report are the machine-readable source of truth; this file is the human summary.

## Snapshot inventory

| release | pipeline | pull_date | path | available |
|---|---|---|---|---|
| jmp2017 | indicators |  | data/derived_data/jmp2017_jmp_washdata_indicators.csv    | no  |
| jmp2019 | indicators |  | data/derived_data/jmp2019_jmp_washdata_indicators.csv    | no  |
| jmp2021 | indicators | 2022-10-19 | data/derived_data/jmp-washdata-indicators.csv            | yes |
| jmp2023 | indicators |  | data/derived_data/jmp2023_jmp_washdata_indicators.csv    | no  |
| jmp2025 | indicators |  | data/derived_data/jmp2025_jmp_washdata_indicators.csv    | no  |
| jmp2019 | raw        | 2020-09-30 | data/derived_data/2020-09-30_jmp_sanitation_raw_data.rds | yes |
| jmp2021 | raw        | 2022-10-19 | data/derived_data/2022-10-19_jmp_sanitation_raw_data.csv | yes |
| jmp2023 | raw        |  | data/derived_data/jmp2023_jmp_sanitation_raw_data.csv    | no  |
| jmp2025 | raw        |  | data/derived_data/jmp2025_jmp_sanitation_raw_data.csv    | no  |

Not yet available: jmp2017 (indicators), jmp2019 (indicators), jmp2023 (indicators), jmp2025 (indicators), jmp2023 (raw), jmp2025 (raw). Recovery of historic releases is tracked in issue #2, the fresh jmp2025 download in issue #4, and the snapshot registry in issue #1.

## Raw survey data (sanitation)

### jmp2019 vs jmp2021 (raw survey data)

Old snapshot: jmp2019 (pulled 2020-09-30, 16,565 data points). New snapshot: jmp2021 (pulled 2022-10-19, 19,557 data points).

Compared on the identity key `iso3 + source + type + year + var_short`: **4,906 added**, 1,914 removed, 792 changed, 13,859 unchanged.

#### Data points by collection year

| year | n_added | n_removed | n_changed | n_unchanged |
|---|---|---|---|---|
| 1991 | 8 | 0 | 0 | 0 |
| 1995 | 0 | 0 | 0 | 4 |
| 1996 | 8 | 0 | 0 | 0 |
| 1999 | 0 | 0 | 0 | 6 |
| 2000 | 38 | 93 | 19 | 790 |
| 2001 | 29 | 58 | 5 | 509 |
| 2002 | 23 | 76 | 20 | 480 |
| 2003 | 14 | 80 | 14 | 760 |
| 2004 | 34 | 47 | 10 | 458 |
| 2005 | 45 | 80 | 16 | 656 |
| 2006 | 49 | 39 | 27 | 1052 |
| 2007 | 17 | 34 | 25 | 715 |
| 2008 | 51 | 62 | 17 | 655 |
| 2009 | 103 | 82 | 41 | 703 |
| 2010 | 113 | 106 | 64 | 989 |
| 2011 | 118 | 69 | 56 | 1067 |
| 2012 | 226 | 241 | 56 | 989 |
| 2013 | 238 | 259 | 79 | 809 |
| 2014 | 296 | 255 | 76 | 950 |
| 2015 | 305 | 222 | 60 | 716 |
| 2016 | 335 | 67 | 72 | 806 |
| 2017 | 589 | 38 | 101 | 658 |
| 2018 | 1115 | 6 | 34 | 81 |
| 2019 | 1021 | 0 | 0 | 6 |
| 2020 | 131 | 0 | 0 | 0 |

#### Top 15 countries by added data points

| iso3 | n_added |
|---|---|
| GTM | 132 |
| UGA | 101 |
| MEX | 95 |
| KOR | 91 |
| BGD | 90 |
| SWE | 85 |
| COL | 82 |
| NGA | 82 |
| BHR | 77 |
| GRC | 76 |
| DOM | 70 |
| IRN | 70 |
| BGR | 67 |
| PAN | 66 |
| KIR | 63 |

## Modelled indicator estimates

Fewer than two indicators snapshots are available (currently: jmp2021), so there is no consecutive release pair to diff yet. See the snapshot inventory above and issues #1, #2 and #4.

## Caveats

- A `changed` data point is not necessarily a corrected value: every JMP release re-models the entire 2000 to present series, so `changed` counts include expected model re-estimation of historical years. This applies above all to the indicator estimates.
- The `added` counts per collection year answer questions like "how many survey data points with collection year 2019 did the newer release add".
- Source labels are normalized before diffing: the 2020-09-30 pull suffixes sources with a two-digit publication year ("CEN00") which later pulls drop ("CEN"), so trailing digits are stripped, and the type "Survey with microdata" (introduced after the 2020 pull) is collapsed into "Survey". Without this normalization not a single identity key matches across the two committed releases. Source renames that go beyond the suffix still appear as a paired `added` and `removed` row.
- Where two source editions collapse onto one normalized key with conflicting values (Poland "ES12"/"ES13", four data points), the newest edition is kept.
- `data/derived_data/2022-10-18_jmp_sanitation_raw_data.csv` is byte-identical to the 2022-10-19 file and is treated as a duplicate, not a separate snapshot.
- Release labels follow the JMP publication held at pull time: the 2020-09-30 pull predates the JMP 2021 update and therefore holds the JMP 2019 release; the 2022-10-19 pull holds the JMP 2021 release.
- Countries without any data are stored as all-NA placeholder rows in the raw snapshots; they are dropped before diffing.

