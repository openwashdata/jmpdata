# header ------------------------------------------------------------------

# Tidy the raw survey-level sanitation data from JMP country files.
# Parameterized port of data-raw/gather/gather_raw_data.R; the legacy script stays
# untouched as the historical record. This script does NOT download
# anything; downloads are issue #4's job.
# Issue: https://github.com/openwashdata/jmpdata/issues/3
#
# Usage:
#   JMP_RELEASE_ID=jmp2025 Rscript data-raw/update/05_tidy_raw_data.R
# Reads <JMP_SNAPSHOT_DIR>/WLD.xlsx and <JMP_SNAPSHOT_DIR>/country_files/
# (one <ISO3>.xlsx per country), writes <JMP_PULL_DATE>-prefixed outputs to
# <JMP_OUTPUT_DIR> and records the snapshot in snapshots_manifest.csv.
# See jmp_update_params() in 00_functions.R for all parameters.

# libraries ---------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))

source(here::here("data-raw/update/00_functions.R"))

# parameters ---------------------------------------------------------------

params <- jmp_update_params()

wld_path <- file.path(params$snapshot_dir, "WLD.xlsx")
country_dir <- file.path(params$snapshot_dir, "country_files")

if (!file.exists(wld_path)) {
    stop("World file not found: ", wld_path,
         ". Set JMP_SNAPSHOT_DIR or download the release first (issue #4).",
         call. = FALSE)
}

if (!dir.exists(country_dir)) {
    stop("Country file directory not found: ", country_dir,
         ". Set JMP_SNAPSHOT_DIR or download the release first (issue #4).",
         call. = FALSE)
}

dir.create(params$output_dir, recursive = TRUE, showWarnings = FALSE)

message("Tidying raw data for ", params$release_id,
        " from ", params$snapshot_dir)

# country list -------------------------------------------------------------

## iso3 codes from the world file (sheet by name, legacy used position 3);
## instead of the legacy hardcoded BLM/MAF exclusion, process the countries
## whose file exists and warn about the rest

country_codes <- read_jmp_sheet(wld_path, c("wat", "Water Data"),
                                reader = "readxl") |>
    select(iso3, name) |>
    unique()

available_iso3 <- list.files(country_dir, pattern = "\\.xlsx$") |>
    str_remove("\\.xlsx$")

missing_iso3 <- setdiff(country_codes$iso3, available_iso3)

if (length(missing_iso3) > 0) {
    warning("No country file for ", length(missing_iso3), " of ",
            nrow(country_codes), " countries in ", country_dir, ": ",
            paste(head(missing_iso3, 10), collapse = ", "),
            if (length(missing_iso3) > 10) ", ..." else "",
            call. = FALSE)
}

country_codes <- country_codes |>
    filter(iso3 %in% available_iso3)

# variable list ------------------------------------------------------------

## variable names live in the first two rows above the Chart Data header;
## the legacy script read them from UGA.xlsx, so prefer UGA when present

var_source_iso3 <- if ("UGA" %in% country_codes$iso3) {
    "UGA"
} else {
    country_codes$iso3[1]
}

var_list <- read_jmp_sheet(
    file.path(country_dir, paste0(var_source_iso3, ".xlsx")),
    "Chart Data", reader = "readxl", skip = 3, col_names = FALSE
) |>
    slice(1:2) |>
    t() |>
    as_tibble(.name_repair = "minimal") |>
    set_names(c("var_long", "var_short"))

write_csv(var_list, file.path(
    params$output_dir, paste0(params$pull_date, "_jmp_wash_variables.csv")
))

## sanitation variables enriched with residence and service chain position;
## enrichment logic ported as-is for output comparability

ssc_levels <- c("open defecation", "sharing", "user interface",
                "containment", "emptying", "transport",
                "FS treatment", "WW treatment")

var_list_san <- var_list |>
    filter(str_starts(var_short, "s_")) |>
    select(var_short, var_long) |>
    arrange(var_short) |>
    ## the unanchored _n/_r/_u detection reproduces the legacy labels,
    ## including their quirks (s_sep_nemp_r is "national" in the committed
    ## 2022 output); the _t line is appended for the 2025 vocabulary where
    ## _t (total) replaced _n, and changes nothing for older releases
    mutate(residence = case_when(
        str_detect(var_short, "_n") ~ "national",
        str_detect(var_short, "_r") ~ "rural",
        str_detect(var_short, "_u") ~ "urban",
        str_detect(var_short, "_t") ~ "national"
    )) |>
    mutate(san_service_chain = case_when(
        str_detect(var_short, "od") ~ "open defecation",
        str_detect(var_short, "imp") ~ "user interface",
        str_detect(var_short, "con|net") ~ "containment",

        # latrines not included because var_short name has "con" in it
        # str_detect(var_short, "lat") ~ "containment",

        str_detect(var_short, "ebo|edl|ero|nemp") ~ "emptying",
        str_detect(var_short, "dtp") ~ "transport",
        str_detect(var_short, "rtp") ~ "transport",
        str_detect(var_short, "treat_fstp") ~ "FS treatment",
        str_detect(var_short, "treat_wtp") ~ "WW treatment",
        str_detect(var_short, "^s_sep|^s_lat|^s_sew") ~ "user interface",
        str_detect(var_short, "shared") ~ "sharing",

        # 2025 vocabulary: s_ns_* ("no service") replaced s_od_*
        str_detect(var_short, "_ns") ~ "open defecation"
    )) |>
    mutate(san_service_chain = factor(san_service_chain,
                                      levels = ssc_levels))

write_csv(var_list_san, file.path(
    params$output_dir,
    paste0(params$pull_date, "_jmp_sanitation_variables_residence.csv")
))

# extract data from country files ------------------------------------------

country_list <- list()

for (name in country_codes$iso3) {

    country_list[[name]] <- read_jmp_sheet(
        file.path(country_dir, paste0(name, ".xlsx")),
        "Chart Data", reader = "readxl", skip = 4, col_names = TRUE
    ) |>
        ## explicit s_ prefix instead of the positional range
        ## s_imp_n:s_shared_r, so new columns cannot silently fall outside
        select(source, type, year, starts_with("s_")) |>
        pivot_longer(
            cols = starts_with("s_"),
            names_to = "var_short",
            values_to = "value"
        ) |>
        filter(!is.na(value)) |>
        mutate(iso3 = name)
}

## countries without a single data point become all-NA placeholder rows,
## as in the legacy output

no_data_iso3 <- country_list |>
    map_int(nrow) |>
    enframe() |>
    filter(value == 0) |>
    pull(name)

no_data_tib <- tibble(
    source = NA_character_,
    type = NA_character_,
    year = NA,
    var_short = NA_character_,
    value = NA,
    iso3 = no_data_iso3
)

# export -------------------------------------------------------------------

jmp_sanitation_raw_data <- country_list |>
    map(\(x) mutate(x, source = as.character(source),
                    type = as.character(type))) |>
    bind_rows() |>
    bind_rows(no_data_tib) |>
    left_join(var_list_san, by = "var_short")

raw_file_stem <- paste0(params$pull_date, "_jmp_sanitation_raw_data")
raw_csv <- paste0(raw_file_stem, ".csv", if (params$compress) ".gz" else "")

jmp_sanitation_raw_data |>
    write_rds(file.path(params$output_dir,
                        paste0(raw_file_stem, ".rds")))

jmp_sanitation_raw_data |>
    write_csv(file.path(params$output_dir, raw_csv))

append_manifest_row(
    manifest_path = file.path(params$output_dir, "snapshots_manifest.csv"),
    release_id = params$release_id,
    pipeline = "raw",
    snapshot_date = params$pull_date,
    file = file.path(params$output_dir_label, raw_csv),
    source = params$source,
    notes = paste0("tidied by 05_tidy_raw_data.R from ",
                   params$snapshot_dir_label, "/country_files")
)

message("Written: ",
        file.path(params$output_dir, paste0(raw_file_stem, ".csv")),
        " (", nrow(jmp_sanitation_raw_data), " rows, ",
        nrow(country_codes), " countries)")
