# JMP snapshot diff report

Generated on 2026-08-20 by `R/update/06_diff_report.R` ([issue #5](https://github.com/openwashdata/jmpinput/issues/5)). All numbers come from committed snapshots; no network access is used. The CSV files next to this report are the machine-readable source of truth; this file is the human summary.

## Snapshot inventory

| release_id | pipeline | snapshot_date | file | source | available | notes |
|---|---|---|---|---|---|---|
| jmp2017 | indicators |  | data/derived_data/jmp2017_jmp_washdata_indicators.csv       |  | no  |  |
| jmp2019 | indicators | 2020-09-03 | data/derived_data/2020-09-03_jmp_washdata_indicators.csv.gz | git-history | yes | tidied by 04_tidy_indicators.R from data/raw_data/snapshots/jmp2019/WLD.xlsx    |
| jmp2021 | indicators | 2022-10-19 | data/derived_data/2022-10-19_jmp-washdata-indicators.csv.gz | live        | yes | jmp2021 indicators baseline; dated gzip copy of the file at commit 782603b      |
| jmp2021 | indicators | 2022-10-19 | data/derived_data/jmp-washdata-indicators.csv               | live        | yes | alias: undated latest, overwritten by each release                              |
| jmp2023 | indicators |  | data/derived_data/jmp2023_jmp_washdata_indicators.csv       |  | no  |  |
| jmp2025 | indicators | 2026-08-20 | data/raw_data/snapshots/jmp2025/WLD.xlsx                    | live        | yes | input: world file, max estimate year 2024; tidy with 04_tidy_indicators.R       |
| jmp2019 | raw        | 2020-09-03 | data/derived_data/2020-09-03_jmp_sanitation_raw_data.rds    | live        | yes | superseded by the 2020-09-30 pull                                               |
| jmp2019 | raw        | 2020-09-30 | data/derived_data/2020-09-30_jmp_sanitation_raw_data.rds    | live        | yes | jmp2019-era raw baseline, as served 2020-09                                     |
| jmp2021 | raw        | 2022-10-18 | data/derived_data/2022-10-18_jmp_sanitation_raw_data.csv    | live        | yes | duplicate of the 2022-10-19 csv (byte-identical)                                |
| jmp2021 | raw        | 2022-10-18 | data/derived_data/2022-10-18_jmp_sanitation_raw_data.rds    | live        | yes | duplicate of the 2022-10-19 rds (byte-identical)                                |
| jmp2021 | raw        | 2022-10-19 | data/derived_data/2022-10-19_jmp_sanitation_raw_data.csv    | live        | yes | jmp2021 raw baseline                                                            |
| jmp2021 | raw        | 2022-10-19 | data/derived_data/2022-10-19_jmp_sanitation_raw_data.rds    | live        | yes | alias of the 2022-10-19 csv (same data, rds format)                             |
| jmp2023 | raw        |  | data/derived_data/jmp2023_jmp_sanitation_raw_data.csv       |  | no  |  |
| jmp2025 | raw        | 2026-08-20 | data/derived_data/2026-08-20_jmp_sanitation_raw_data.csv    | live        | yes | tidied by 05_tidy_raw_data.R from data/raw_data/snapshots/jmp2025/country_files |
| jmp2025 | raw        | 2026-08-20 | data/raw_data/snapshots/jmp2025/country_files               | live        | yes | input: 232 country files, 0 failed; tidy with 05_tidy_raw_data.R                |

Not yet available: jmp2017 (indicators), jmp2023 (indicators), jmp2023 (raw). Recovery of historic releases is tracked in issue #2, the fresh jmp2025 download in issue #4, and the snapshot registry in issue #1.

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

### jmp2021 vs jmp2025 (raw survey data)

Old snapshot: jmp2021 (pulled 2022-10-19, 19,557 data points). New snapshot: jmp2025 (pulled 2026-08-20, 26,925 data points).

Compared on the identity key `iso3 + source + type + year + var_short`: **9,372 added**, 2,004 removed, 1,215 changed, 16,338 unchanged.

#### Data points by collection year

| year | n_added | n_removed | n_changed | n_unchanged |
|---|---|---|---|---|
| 1991 | 8 | 8 | 0 | 0 |
| 1995 | 0 | 0 | 0 | 4 |
| 1996 | 8 | 8 | 0 | 0 |
| 1999 | 0 | 0 | 0 | 6 |
| 2000 | 29 | 54 | 41 | 752 |
| 2001 | 74 | 77 | 13 | 453 |
| 2002 | 51 | 50 | 31 | 442 |
| 2003 | 64 | 36 | 26 | 726 |
| 2004 | 56 | 29 | 37 | 436 |
| 2005 | 75 | 78 | 43 | 596 |
| 2006 | 123 | 45 | 39 | 1044 |
| 2007 | 94 | 59 | 46 | 652 |
| 2008 | 135 | 51 | 43 | 629 |
| 2009 | 139 | 75 | 67 | 705 |
| 2010 | 205 | 84 | 79 | 1003 |
| 2011 | 185 | 101 | 87 | 1053 |
| 2012 | 390 | 261 | 81 | 929 |
| 2013 | 335 | 203 | 77 | 846 |
| 2014 | 339 | 218 | 86 | 1018 |
| 2015 | 422 | 226 | 71 | 784 |
| 2016 | 272 | 96 | 91 | 1026 |
| 2017 | 360 | 82 | 82 | 1184 |
| 2018 | 668 | 93 | 77 | 1060 |
| 2019 | 727 | 55 | 90 | 882 |
| 2020 | 1047 | 15 | 8 | 108 |
| 2021 | 1302 | 0 | 0 | 0 |
| 2022 | 1355 | 0 | 0 | 0 |
| 2023 | 765 | 0 | 0 | 0 |
| 2024 | 142 | 0 | 0 | 0 |
|  | 2 | 0 | 0 | 0 |

#### Top 15 countries by added data points

| iso3 | n_added |
|---|---|
| MEX | 225 |
| PER | 194 |
| KHM | 182 |
| HUN | 177 |
| CRI | 176 |
| KEN | 171 |
| MLT | 169 |
| GRC | 152 |
| BGD | 144 |
| NER | 144 |
| NGA | 130 |
| ECU | 125 |
| BLM | 120 |
| MAF | 120 |
| EST | 116 |

## Modelled indicator estimates

### jmp2019 vs jmp2021 (indicator estimates)

Old snapshot: jmp2019 (pulled 2020-09-03, 288,144 data points). New snapshot: jmp2021 (pulled 2022-10-19, 339,066 data points).

Compared on the identity key `iso3 + year + residence + var_short + indicator_type`: **50,922 added**, 0 removed, 134,201 changed, 153,943 unchanged.

#### Data points by estimate year

| year | n_added | n_removed | n_changed | n_unchanged |
|---|---|---|---|---|
| 2000 | 138 | 0 | 6902 | 9106 |
| 2001 | 138 | 0 | 7039 | 8969 |
| 2002 | 138 | 0 | 7082 | 8926 |
| 2003 | 138 | 0 | 7072 | 8936 |
| 2004 | 138 | 0 | 7138 | 8870 |
| 2005 | 138 | 0 | 7240 | 8768 |
| 2006 | 138 | 0 | 7376 | 8632 |
| 2007 | 138 | 0 | 7406 | 8602 |
| 2008 | 138 | 0 | 7495 | 8513 |
| 2009 | 138 | 0 | 7534 | 8474 |
| 2010 | 138 | 0 | 7630 | 8378 |
| 2011 | 138 | 0 | 7748 | 8260 |
| 2012 | 138 | 0 | 7781 | 8227 |
| 2013 | 138 | 0 | 7816 | 8192 |
| 2014 | 138 | 0 | 7802 | 8206 |
| 2015 | 138 | 0 | 7822 | 8186 |
| 2016 | 138 | 0 | 7724 | 8284 |
| 2017 | 138 | 0 | 7594 | 8414 |
| 2018 | 16146 | 0 | 0 | 0 |
| 2019 | 16146 | 0 | 0 | 0 |
| 2020 | 16146 | 0 | 0 | 0 |

## Caveats

- A `changed` data point is not necessarily a corrected value: every JMP release re-models the entire 2000 to present series, so `changed` counts include expected model re-estimation of historical years. This applies above all to the indicator estimates.
- The `added` counts per collection year answer questions like "how many survey data points with collection year 2019 did the newer release add".
- Raw snapshots are normalized before diffing: the 2020-09-30 pull suffixes sources with a two-digit publication year ("CEN00") which later pulls drop ("CEN"), so trailing digits are stripped; type labels are mapped to English base categories (the 2022 pull split "Survey with microdata" out of "Survey", the 2025 release localizes types into the country language); and the 2025 variable renames are mapped back to the legacy vocabulary (suffix _t to _n, s_ns_* to s_od_*, verified value-identical on matched keys). Without this normalization not a single identity key matches across releases. Renames that go beyond these rules still appear as a paired `added` and `removed` row.
- Where two source editions collapse onto one normalized key with conflicting values (Poland "ES12"/"ES13", four data points), the newest edition is kept.
- `data/derived_data/2022-10-18_jmp_sanitation_raw_data.csv` is byte-identical to the 2022-10-19 file and is treated as a duplicate, not a separate snapshot.
- Release labels follow the JMP publication held at pull time: the 2020-09-30 pull predates the JMP 2021 update and therefore holds the JMP 2019 release; the 2022-10-19 pull holds the JMP 2021 release.
- Countries without any data are stored as all-NA placeholder rows in the raw snapshots; they are dropped before diffing.

