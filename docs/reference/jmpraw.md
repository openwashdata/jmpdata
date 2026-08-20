# jmpraw: Survey-Level Sanitation Input Data from the WHO/UNICEF JMP

Survey, census and administrative data points on sanitation that
underlie the estimates of the WHO/UNICEF Joint Monitoring Programme for
Water Supply, Sanitation and Hygiene (JMP), extracted from the country
files published on washdata.org. Packaged from the JMP 2025 release,
pulled 2026-08-20.

## Usage

``` r
jmpraw
```

## Format

A tibble with 26926 rows and 9 variables

- source:

  Code of the data source underlying the data point (for example MICS,
  DHS, CEN), as published in the JMP country file

- type:

  Source type label (Survey, Census, Admin, Other); localized into the
  country language in the JMP 2025 release (for example Encuesta,
  Recensement)

- year:

  Year of data collection

- var_short:

  JMP short variable code of the sanitation variable (for example
  s_imp_u)

- value:

  Value of the variable, in percent of population

- iso3:

  ISO 3166-1 alpha-3 country code

- var_long:

  Label of the sanitation variable, as published in the JMP country file

- residence:

  Residence level of the variable: national, rural or urban

- san_service_chain:

  Sanitation service chain stage of the variable: open defecation,
  sharing, user interface, containment, emptying, transport, FS
  treatment or WW treatment

## Source

<https://washdata.org>
