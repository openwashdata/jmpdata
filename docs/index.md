# jmpdata

The goal of jmpdata is to make the data behind the WHO/UNICEF Joint
Monitoring Programme for Water Supply, Sanitation and Hygiene (JMP)
available as tidy, documented R datasets. The package contains two data
resources from the JMP 2025 release, both prepared by the update
pipeline documented in `data-raw/UPDATING.md`:

- `jmpraw`: the survey-level input data on sanitation that underlies the
  JMP estimates, extracted from the country files published on
  [washdata.org](https://washdata.org).
- `jmpindicators`: the modelled JMP indicator estimates for drinking
  water, sanitation and hygiene from the JMP world file, with variable
  codes normalized to the legacy JMP vocabulary so snapshots stay
  comparable across releases.

## Installation

You can install the development version of jmpdata from
[GitHub](https://github.com/) with:

``` r

# install.packages("devtools")
devtools::install_github("openwashdata/jmpdata")
```

``` r

## Run the following code in console if you don't have the packages
## install.packages(c("dplyr", "knitr", "readr", "stringr", "gt", "kableExtra"))
library(dplyr)
library(knitr)
library(readr)
library(stringr)
library(gt)
library(kableExtra)
```

Alternatively, you can download the individual datasets from the table
below. `jmpraw` is available as CSV and XLSX; `jmpindicators` is
available as a gzip-compressed CSV only, because the uncompressed file
is about 38 MB (R’s
[`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html)
and most spreadsheet tools open `.csv.gz` files directly).

1.  Click a download link. A window opens that displays the file in your
    browser, or downloads it directly.
2.  If the file is displayed, right-click anywhere inside the window and
    select “Save Page As…”.
3.  Save the file in a folder of your choice.

| dataset | CSV | XLSX |
|:---|:---|:---|
| jmpraw | [Download CSV](https://github.com/openwashdata/jmpdata/raw/main/inst/extdata/jmpraw.csv) | [Download XLSX](https://github.com/openwashdata/jmpdata/raw/main/inst/extdata/jmpraw.xlsx) |
| jmpindicators | [Download CSV (gzip)](https://github.com/openwashdata/jmpdata/raw/main/inst/extdata/jmpindicators.csv.gz) |  |

## Data

The package provides access to the input data and the modelled indicator
estimates of the WHO/UNICEF Joint Monitoring Programme for Water Supply,
Sanitation and Hygiene (JMP), packaged from the JMP 2025 release (pulled
2026-08-20).

``` r

library(jmpdata)
```

### jmpraw

The dataset `jmpraw` contains the survey, census and administrative data
points on sanitation that underlie the JMP estimates, one row per
country, source, collection year and sanitation variable. It has 26926
observations and 9 variables.

``` r

jmpraw |>
  head(3) |>
  gt::gt() |>
  gt::as_raw_html()
```

| source | type | year | var_short | value | iso3 | var_long | residence | san_service_chain |
|:---|:---|---:|:---|---:|:---|:---|:---|:--:|
| MICS | Survey | 2003 | s_imp_u | 44.2 | AFG | Improved | urban | user interface |
| MICS | Survey | 2003 | s_sew_u | 8.2 | AFG | Sewer connection | urban | user interface |
| MICS | Survey | 2003 | s_lat_u | 36.0 | AFG | Latrines and other | urban | user interface |

For an overview of the variable names, see the following table.

| variable_name | variable_type | description |
|:---|:---|:---|
| source | character | Code of the data source underlying the data point (for example MICS, DHS, CEN), as published in the JMP country file |
| type | character | Source type label (Survey, Census, Admin, Other); localized into the country language in the JMP 2025 release (for example Encuesta, Recensement) |
| year | numeric | Year of data collection |
| var_short | character | JMP short variable code of the sanitation variable (for example s_imp_u) |
| value | numeric | Value of the variable, in percent of population |
| iso3 | character | ISO 3166-1 alpha-3 country code |
| var_long | character | Label of the sanitation variable, as published in the JMP country file |
| residence | character | Residence level of the variable: national, rural or urban |
| san_service_chain | factor | Sanitation service chain stage of the variable: open defecation, sharing, user interface, containment, emptying, transport, FS treatment or WW treatment |

### jmpindicators

The dataset `jmpindicators` contains the modelled JMP indicator
estimates for drinking water, sanitation and hygiene, one row per
country, estimate year, residence level and indicator. It has 424575
observations and 12 variables.

``` r

jmpindicators |>
  head(3) |>
  gt::gt() |>
  gt::as_raw_html()
```

| name | iso3 | year | pop_t | prop_u | arc_hyg_bas_u | var_short | percent | residence | service | indicator_type | indicator |
|:---|:---|---:|---:|---:|---:|:---|---:|:---|:---|:---|:---|
| Afghanistan | AFG | 2000 | 20130.33 | 22.078 | NA | san_bas | 19.568569 | rural | sanitation | sanitation_ladder | At least basic |
| Afghanistan | AFG | 2000 | 20130.33 | 22.078 | NA | san_lim | 2.597013 | rural | sanitation | sanitation_ladder | Limited (shared) |
| Afghanistan | AFG | 2000 | 20130.33 | 22.078 | NA | san_unimp | 48.719439 | rural | sanitation | sanitation_ladder | Unimproved |

For an overview of the variable names, see the following table.

| variable_name | variable_type | description |
|:---|:---|:---|
| name | character | Country, area or territory name as published in the JMP world file |
| iso3 | character | ISO 3166-1 alpha-3 country code |
| year | integer | Year of the modelled estimate |
| pop_t | numeric | Total population in thousands, as used by the JMP model (named pop_n in pre-2025 world files) |
| prop_u | numeric | Share of the population living in urban areas, in percent |
| arc_hyg_bas_u | numeric | Annual rate of change in urban basic hygiene coverage; retained as an identifier column from the legacy pipeline and all NA in this release |
| var_short | character | JMP short variable code of the indicator, normalized to the legacy JMP vocabulary with the residence suffix removed (for example san_sm, wat_bas) |
| percent | numeric | Modelled coverage estimate, in percent of population |
| residence | character | Residence level of the estimate: national, rural or urban |
| service | character | WASH service area of the indicator: water, sanitation or hygiene |
| indicator_type | character | Indicator grouping: sanitation_technology, safely_managed_sanitation, sanitation_ladder, water_technology, safely_managed_drinking_water, water_ladder, hygiene_ladder or bathing_facilities |
| indicator | character | Indicator label within the grouping (for example Safely managed, Basic, Limited) |

## Example

How many survey-level sanitation data points does each JMP release hold
for Uganda, by source type?

``` r

library(jmpdata)
library(dplyr)

jmpraw |>
  filter(iso3 == "UGA") |>
  count(type, sort = TRUE)
#> # A tibble: 4 × 2
#>   type                      n
#>   <chr>                 <int>
#> 1 Survey with microdata   292
#> 2 Survey                   43
#> 3 Census                   18
#> 4 Admin                    10
```

Safely managed sanitation in Uganda over time, from the modelled
estimates:

``` r

jmpindicators |>
  filter(iso3 == "UGA",
         indicator == "Safely managed",
         service == "sanitation",
         residence == "national",
         year %in% c(2000, 2010, 2020, 2024)) |>
  select(year, percent)
#> # A tibble: 4 × 2
#>    year percent
#>   <int>   <dbl>
#> 1  2000      NA
#> 2  2010      NA
#> 3  2020      NA
#> 4  2024      NA
```

## License

Data are available as
[CC-BY](https://github.com/openwashdata/jmpdata/blob/main/LICENSE.md).

## Citation

Please cite this package using:

``` r

citation("jmpdata")
#> To cite package 'jmpdata' in publications use:
#> 
#>   Schöbitz L (2026). "jmpdata: Input Data and Indicator Estimates from
#>   the WHO/UNICEF Joint Monitoring Programme."
#>   <https://github.com/openwashdata/jmpdata>.
#> 
#> A BibTeX entry for LaTeX users is
#> 
#>   @Misc{schobitz:2026,
#>     title = {jmpdata: Input Data and Indicator Estimates from the WHO/UNICEF Joint Monitoring Programme},
#>     author = {Lars Schöbitz},
#>     year = {2026},
#>     url = {https://github.com/openwashdata/jmpdata},
#>     abstract = {Contains two data resources from the WHO/UNICEF Joint Monitoring Programme (JMP) for Water Supply, Sanitation and Hygiene. `jmpraw` holds the survey-level input data on sanitation that underlies the JMP estimates, collected from the country files published on <https://washdata.org>. `jmpindicators` holds the modelled JMP indicator estimates for water, sanitation and hygiene from the JMP world file. Both datasets are packaged from the JMP 2025 release.},
#>     version = {0.1.0},
#>   }
```
