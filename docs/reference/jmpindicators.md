# jmpindicators: Modelled WASH Indicator Estimates from the WHO/UNICEF JMP

Modelled indicator estimates for drinking water, sanitation and hygiene
from the world file of the WHO/UNICEF Joint Monitoring Programme for
Water Supply, Sanitation and Hygiene (JMP), published on washdata.org.
Variable codes are normalized to the legacy JMP vocabulary so snapshots
stay comparable across releases. Packaged from the JMP 2025 release,
pulled 2026-08-20.

## Usage

``` r
jmpindicators
```

## Format

A tibble with 424575 rows and 12 variables

- name:

  Country, area or territory name as published in the JMP world file

- iso3:

  ISO 3166-1 alpha-3 country code

- year:

  Year of the modelled estimate

- pop_t:

  Total population in thousands, as used by the JMP model (named pop_n
  in pre-2025 world files)

- prop_u:

  Share of the population living in urban areas, in percent

- arc_hyg_bas_u:

  Annual rate of change in urban basic hygiene coverage; retained as an
  identifier column from the legacy pipeline and all NA in this release

- var_short:

  JMP short variable code of the indicator, normalized to the legacy JMP
  vocabulary with the residence suffix removed (for example san_sm,
  wat_bas)

- percent:

  Modelled coverage estimate, in percent of population

- residence:

  Residence level of the estimate: national, rural or urban

- service:

  WASH service area of the indicator: water, sanitation or hygiene

- indicator_type:

  Indicator grouping: sanitation_technology, safely_managed_sanitation,
  sanitation_ladder, water_technology, safely_managed_drinking_water,
  water_ladder, hygiene_ladder or bathing_facilities

- indicator:

  Indicator label within the grouping (for example Safely managed,
  Basic, Limited)

## Source

<https://washdata.org>
