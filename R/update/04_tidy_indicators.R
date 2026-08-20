# header ------------------------------------------------------------------

# Tidy the modelled indicator estimates from a JMP world file (WLD.xlsx).
# Parameterized port of R/gather/gather_jmp_data.R; the legacy script stays
# untouched as the historical record.
# Issue: https://github.com/openwashdata/jmpinput/issues/3
#
# Usage:
#   JMP_RELEASE_ID=jmp2025 Rscript R/update/04_tidy_indicators.R
# Reads <JMP_SNAPSHOT_DIR>/WLD.xlsx, writes <JMP_PULL_DATE>-prefixed outputs
# to <JMP_OUTPUT_DIR> and records the snapshot in snapshots_manifest.csv.
# See jmp_update_params() in 00_functions.R for all parameters.
#
# The enrichment logic is ported as-is for output comparability, including
# one legacy accident kept deliberately: the gather range ended at
# hyg_nfac_u, which leaves arc_hyg_bas_u behind as an id column that then
# appears in every output row.

# libraries ---------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))

source(here::here("R/update/00_functions.R"))

# parameters ---------------------------------------------------------------

params <- jmp_update_params()

wld_path <- file.path(params$snapshot_dir, "WLD.xlsx")

if (!file.exists(wld_path)) {
    stop("World file not found: ", wld_path,
         ". Set JMP_SNAPSHOT_DIR or download the release first (issue #4).",
         call. = FALSE)
}

dir.create(params$output_dir, recursive = TRUE, showWarnings = FALSE)

message("Tidying indicators for ", params$release_id,
        " from ", params$snapshot_dir)

# load data ----------------------------------------------------------------

## sheets by name, never by position (legacy used indices 3/5/7); openxlsx
## as in the legacy script so column types are guessed identically

jmp_world_wat <- read_jmp_sheet(wld_path, c("wat", "Water Data"),
                                reader = "openxlsx")
jmp_world_san <- read_jmp_sheet(wld_path, c("san", "Sanitation Data"),
                                reader = "openxlsx")
jmp_world_hyg <- read_jmp_sheet(wld_path, c("hyg", "Hygiene Data"),
                                reader = "openxlsx")

## hand-curated variable names, maintained in the repo
jmp_vars <- read_csv(
    here::here("data/derived_data/jmp_wash_variables_complete.csv"),
    show_col_types = FALSE
) |>
    select(-name) |>
    filter(!is.na(var_long)) |>
    unique()

# manipulate data ----------------------------------------------------------

## keep the identifying columns plus every numeric indicator column; this
## drops the character region_* columns exactly like the legacy
## select(name, iso3, where(is.double)). The 2020- and 2025-era world
## files carry numeric helper columns that are not indicators; the 2022
## file has none of them, so any_of() is a no-op there.

helper_cols <- c("year2", "pop_n2", "blank", "latestyear")

jmp_world_wat_join <- jmp_world_wat |>
    select(name, iso3, where(is.double)) |>
    select(-any_of(helper_cols))

jmp_world_san_join <- jmp_world_san |>
    select(name, iso3, where(is.double)) |>
    select(-any_of(helper_cols))

jmp_world_hyg_join <- jmp_world_hyg |>
    select(name, iso3, where(is.double)) |>
    select(-any_of(helper_cols))

## the three sheets share the identifying columns; computing the join key
## as their intersection replaces the legacy natural join and absorbs the
## population column rename (pop_n through 2022, pop_t from 2025)

join_cols <- Reduce(intersect, list(
    names(jmp_world_wat_join),
    names(jmp_world_san_join),
    names(jmp_world_hyg_join)
))

## id columns that stay wide when the indicator columns are gathered;
## arc_hyg_bas_u is the preserved legacy accident described in the header

id_cols <- c("name", "iso3", "year", "pop_n", "pop_t", "prop_u",
             "arc_hyg_bas_u")

jmp_world_tidy <- jmp_world_wat_join |>
    left_join(jmp_world_san_join, by = join_cols) |>
    left_join(jmp_world_hyg_join, by = join_cols) |>
    select(-sl) |>
    relocate(name, iso3) |>

    ## explicit prefix selection instead of the positional range
    ## wat_bas_n:hyg_nfac_u, so new columns cannot silently fall outside
    pivot_longer(
        cols = starts_with(c("wat_", "san_", "hyg_", "arc_")) &
            !any_of(id_cols),
        names_to = "var_short",
        values_to = "percent"
    ) |>

    ## the 2025 release renamed the vocabulary; map onto the legacy names
    ## so the hand-curated lookup resolves and tidy snapshots stay
    ## schema-consistent across releases (no-op for pre-2023 files)
    mutate(var_short = normalize_indicator_vars(var_short)) |>

    ## warns and records unknown variables before dropping them
    join_jmp_vars(jmp_vars,
                  output_dir = params$output_dir,
                  pull_date = params$pull_date) |>
    mutate(
        residence = case_when(
            str_detect(var_short, "_n$") ~ "national",
            str_detect(var_short, "_r$") ~ "rural",
            str_detect(var_short, "_u$") ~ "urban"
        )
    ) |>
    mutate(var_short = str_replace(var_short, "_n$", "")) |>
    mutate(var_short = str_replace(var_short, "_r$", "")) |>
    mutate(var_short = str_replace(var_short, "_u$", "")) |>
    mutate(
        service = case_when(
            str_detect(var_short, "^san") ~ "sanitation",
            str_detect(var_short, "^wat") ~ "water",
            str_detect(var_short, "^hyg") ~ "hygiene"
        )
    )

# enrich data --------------------------------------------------------------

## sanitation

jmp_world_tidy_san <- jmp_world_tidy |>
    filter(service == "sanitation") |>
    mutate(sanitation_technology = case_when(
        str_detect(var_short, "(lat|sep|sew)$") ~ var_long
    )) |>
    mutate(safely_managed_sanitation = case_when(
        str_detect(var_short, "sm$") ~ var_long
    )) |>
    mutate(sanitation_ladder = case_when(
        str_detect(var_short, "(bas|lim|unimp|od)$") ~ var_long
    )) |>
    pivot_longer(
        cols = all_of(c("sanitation_technology",
                        "safely_managed_sanitation",
                        "sanitation_ladder")),
        names_to = "indicator_type",
        values_to = "indicator"
    ) |>
    filter(!is.na(indicator))

## water

jmp_world_tidy_wat <- jmp_world_tidy |>
    filter(service == "water") |>
    mutate(water_technology = case_when(
        str_detect(var_short, "(pip|npip)$") ~ var_long
    )) |>
    mutate(safely_managed_drinking_water = case_when(
        str_detect(var_short, "(ses|ble|ity)$") ~ var_long
    )) |>
    mutate(water_ladder = case_when(
        str_detect(var_short, "(bas|lim|unimp|sur)$") ~ var_long
    )) |>
    pivot_longer(
        cols = all_of(c("water_technology",
                        "safely_managed_drinking_water",
                        "water_ladder")),
        names_to = "indicator_type",
        values_to = "indicator"
    ) |>
    filter(!is.na(indicator))

## hygiene. The legacy script had no filter(!is.na(indicator)) here, but
## every hygiene variable of the 2019/2022 files matches the ladder
## pattern, so adding the filter for the two-type pivot below is a no-op
## for reproducing the committed outputs (regression-checked). The
## bathing indicator_type covers the JMP 2025 bathing facility variables
## (issue #9).

jmp_world_tidy_hyg <- jmp_world_tidy |>
    filter(service == "hygiene") |>
    mutate(hygiene_ladder = case_when(
        str_detect(var_short, "(bas|lim|nfac)$") ~ var_long
    )) |>
    mutate(bathing_facilities = case_when(
        str_detect(var_short, "(bfacw|bfac)$") ~ var_long
    )) |>
    pivot_longer(
        cols = all_of(c("hygiene_ladder", "bathing_facilities")),
        names_to = "indicator_type",
        values_to = "indicator"
    ) |>
    filter(!is.na(indicator))

## bind rows back together

jmp_world_tidy_enriched <- jmp_world_tidy_san |>
    bind_rows(
        jmp_world_tidy_wat,
        jmp_world_tidy_hyg
    ) |>
    mutate(percent = as.double(percent)) |>
    select(-var_long)

# export -------------------------------------------------------------------

indicators_file <- paste0(params$pull_date, "_jmp_washdata_indicators.csv",
                          if (params$compress) ".gz" else "")

write_csv(jmp_world_tidy_enriched,
          file.path(params$output_dir, indicators_file))

append_manifest_row(
    manifest_path = file.path(params$output_dir, "snapshots_manifest.csv"),
    release_id = params$release_id,
    pipeline = "indicators",
    snapshot_date = params$pull_date,
    file = file.path(params$output_dir_label, indicators_file),
    source = params$source,
    notes = paste0("tidied by 04_tidy_indicators.R from ",
                   params$snapshot_dir_label, "/WLD.xlsx")
)

message("Written: ", file.path(params$output_dir, indicators_file))

# teaching subset (optional, needs World Bank income groups) ---------------

## CLASS.xlsx is not committed; the main indicators CSV above never
## depends on it

class_path <- c(
    file.path(params$snapshot_dir, "CLASS.xlsx"),
    here::here("data/raw_data/CLASS.xlsx")
)
class_path <- class_path[file.exists(class_path)][1]

if (is.na(class_path)) {

    warning("data/raw_data/CLASS.xlsx not found; skipping the income-group ",
            "teaching subset. Download it from ",
            "https://datacatalogfiles.worldbank.org/ddh-published/0037712/DR0090755/CLASS.xlsx ",
            "(landing page: https://datahelpdesk.worldbank.org/knowledgebase/articles/906519).",
            call. = FALSE)

} else {

    safely_managed_sml <- jmp_world_tidy_enriched |>
        mutate(
            pop = case_when(
                residence == "national" ~ pop_n * 1000,
                residence == "urban" ~ pop_n * 1000 * prop_u / 100,
                residence == "rural" ~ pop_n * 1000 * (100 - prop_u) / 100
            )
        ) |>
        select(-prop_u, -pop_n, -arc_hyg_bas_u, -var_short) |>
        filter(service == "sanitation") |>
        filter(indicator == "Safely managed") |>
        select(-indicator_type, -service) |>
        filter(year %in% c(2000, 2010, 2020))

    wb_income_cat_tidy <- readxl::read_xlsx(class_path, sheet = 1) |>
        select(iso3 = Code, region = Region, income_grp = `Income group`) |>
        mutate(income_id = case_when(
            income_grp == "High income" ~ "HIC",
            income_grp == "Low income" ~ "LIC",
            income_grp == "Lower middle income" ~ "LMC",
            income_grp == "Upper middle income" ~ "UMC"
        )) |>
        select(-income_grp)

    sml_file <- paste0(params$pull_date,
                       "_jmp_washdata_indicators_safely_managed_sml.csv")

    safely_managed_sml |>
        left_join(wb_income_cat_tidy, by = "iso3") |>
        write_csv(file.path(params$output_dir, sml_file))

    message("Written: ", file.path(params$output_dir, sml_file))
}
