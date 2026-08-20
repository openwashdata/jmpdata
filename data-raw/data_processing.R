# Description ------------------------------------------------------------------
# Packaging step for the jmpinput data package: turns the latest dated
# outputs of the update pipeline (data-raw/update/run_update.R, see
# data-raw/UPDATING.md) into the package datasets and human-readable
# exports. Re-run after a pipeline update; latest() picks the newest
# dated files, so no edits are needed here.

# Load packages ----------------------------------------------------------------
## Run the following code in console if you don't have the packages
## install.packages(c("usethis", "fs", "here", "readr", "openxlsx"))
library(usethis)
library(fs)
library(here)
library(readr)
library(openxlsx)

# Read data --------------------------------------------------------------------
## newest dated pipeline output per pattern; the ISO date prefix sorts
## lexicographically

latest <- function(pattern) {
    files <- sort(list.files(here::here("data-raw/derived_data"),
                             pattern = pattern, full.names = TRUE))
    if (length(files) == 0) {
        stop("No file in data-raw/derived_data matches ", pattern,
             call. = FALSE)
    }
    files[length(files)]
}

## survey-level sanitation input data (05_tidy_raw_data.R output); the rds
## preserves the pipeline's column types
jmpraw <- read_rds(
    latest("^\\d{4}-\\d{2}-\\d{2}_jmp_sanitation_raw_data\\.rds$")
)

## modelled indicator estimates (04_tidy_indicators.R output); explicit
## column types because arc_hyg_bas_u is nearly all NA and would otherwise
## be guessed as logical
jmpindicators <- read_csv(
    latest("^\\d{4}-\\d{2}-\\d{2}_jmp_washdata_indicators\\.csv\\.gz$"),
    col_types = cols(
        name = col_character(),
        iso3 = col_character(),
        year = col_integer(),
        pop_t = col_double(),
        prop_u = col_double(),
        arc_hyg_bas_u = col_double(),
        var_short = col_character(),
        percent = col_double(),
        residence = col_character(),
        service = col_character(),
        indicator_type = col_character(),
        indicator = col_character()
    )
)

# Export Data ------------------------------------------------------------------
usethis::use_data(jmpraw, overwrite = TRUE, compress = "xz")
usethis::use_data(jmpindicators, overwrite = TRUE, compress = "xz")

fs::dir_create(here::here("inst", "extdata"))

## human-readable exports; no xlsx for jmpindicators (about 38 MB
## uncompressed, and inst/ ships in every package tarball)
readr::write_csv(jmpraw, here::here("inst", "extdata", "jmpraw.csv"))
openxlsx::write.xlsx(jmpraw, here::here("inst", "extdata", "jmpraw.xlsx"))
readr::write_csv(jmpindicators,
                 here::here("inst", "extdata", "jmpindicators.csv.gz"))
