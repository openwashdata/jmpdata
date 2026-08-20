# header ------------------------------------------------------------------

# Download the current JMP release from washdata.org: the world file and
# all ~230 country files, into gitignored data-raw/raw_data/snapshots/<id>/.
# Replaces the download logic embedded in the legacy gather scripts.
# Issue: https://github.com/openwashdata/jmpinput/issues/4
#
# Must run on a local machine; the remote sandbox cannot reach
# washdata.org. Resumable: files that already downloaded completely are
# skipped, so an interrupted run continues instead of restarting.
# Requests are paced (washdata.org is a small site; the jmpwashdata
# package explicitly avoids unnecessary load on it).
#
# Usage:
#   Rscript data-raw/update/03_download_current.R            # jmp2025 defaults
# then tidy the snapshot:
#   JMP_RELEASE_ID=jmp2025 Rscript data-raw/update/05_tidy_raw_data.R
#   JMP_RELEASE_ID=jmp2025 Rscript data-raw/update/04_tidy_indicators.R

# libraries ---------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))

source(here::here("data-raw/update/00_functions.R"))

# parameters ---------------------------------------------------------------

params <- jmp_update_params()

snapshot_dir <- params$snapshot_dir
country_dir <- file.path(snapshot_dir, "country_files")

dir.create(country_dir, recursive = TRUE, showWarnings = FALSE)

options(timeout = 300)

## pause between requests, in seconds
pacing <- 0.5

## country files that stopped existing on washdata.org in 2022; attempted
## anyway in case a new release restores them, labelled in the failure log
## if they still fail
known_missing <- c("BLM", "MAF")

message("Downloading ", params$release_id, " snapshot to ", snapshot_dir)

# world file ----------------------------------------------------------------

wld_path <- file.path(snapshot_dir, "WLD.xlsx")

if (is_xlsx(wld_path)) {
    message("World file already downloaded, skipping")
} else {
    message("Downloading world file")
    wld_status <- download_jmp_country("WLD", wld_path)
    if (wld_status != "ok") {
        stop("World file download failed (", wld_status, ")", call. = FALSE)
    }
    Sys.sleep(pacing)
}

## validate: the three data sheets must be present (names differ between
## releases, see read_jmp_sheet) and the maximum estimate year is reported

sheets <- openxlsx::getSheetNames(wld_path)

for (candidates in list(c("wat", "Water Data"),
                        c("san", "Sanitation Data"),
                        c("hyg", "Hygiene Data"))) {
    if (length(intersect(candidates, sheets)) == 0) {
        stop("World file is missing a data sheet: none of ",
             paste0("'", candidates, "'", collapse = ", "),
             " present. Available sheets: ",
             paste(sheets, collapse = ", "), call. = FALSE)
    }
}

jmp_world_wat <- read_jmp_sheet(wld_path, c("wat", "Water Data"),
                                reader = "readxl")

max_year <- max(jmp_world_wat$year, na.rm = TRUE)

message("World file validated: data sheets present, max estimate year ",
        max_year,
        if (max_year == 2024) " (as expected for the JMP 2025 release)"
        else " (expected 2024 for the JMP 2025 release; check which release washdata.org is serving)")

# country files --------------------------------------------------------------

country_codes <- jmp_world_wat |>
    select(iso3, name) |>
    unique()

message("Downloading ", nrow(country_codes), " country files (resumable, ",
        pacing, "s pacing)")

results <- character()
n_downloaded <- 0

for (iso3 in country_codes$iso3) {

    dest <- file.path(country_dir, paste0(iso3, ".xlsx"))

    if (is_xlsx(dest)) {
        results[iso3] <- "ok"
        next
    }

    results[iso3] <- download_jmp_country(iso3, dest)
    n_downloaded <- n_downloaded + 1

    if (results[iso3] != "ok") {
        message("  ", iso3, ": ", results[iso3])
    } else if (n_downloaded %% 25 == 0) {
        message("  ", n_downloaded, " files downloaded")
    }

    Sys.sleep(pacing)
}

# failure log ----------------------------------------------------------------

## written next to the snapshot; header-only when everything succeeded

failures <- enframe(results, name = "iso3", value = "status") |>
    filter(status != "ok") |>
    mutate(note = if_else(iso3 %in% known_missing,
                          "known missing since 2022", NA_character_))

failure_log <- file.path(
    snapshot_dir, paste0(params$pull_date, "_download_failures.csv")
)
write_csv(failures, failure_log)

n_ok <- sum(results == "ok")

message("Done: ", n_ok, " of ", nrow(country_codes),
        " country files present (", n_downloaded,
        " downloaded this run), ", nrow(failures), " failed. Failure log: ",
        failure_log)

# register the raw inputs in the manifest ------------------------------------

## "input" rows are listed in the inventory but excluded from diff chains;
## the tidy scripts (04/05) register the diffable snapshots

manifest_path <- here::here("data-raw/derived_data/snapshots_manifest.csv")

append_manifest_row(
    manifest_path,
    release_id = params$release_id,
    pipeline = "indicators",
    snapshot_date = params$pull_date,
    file = file.path(params$snapshot_dir_label, "WLD.xlsx"),
    source = params$source,
    notes = paste0("input: world file, max estimate year ", max_year,
                   "; tidy with 04_tidy_indicators.R")
)

append_manifest_row(
    manifest_path,
    release_id = params$release_id,
    pipeline = "raw",
    snapshot_date = params$pull_date,
    file = file.path(params$snapshot_dir_label, "country_files"),
    source = params$source,
    notes = paste0("input: ", n_ok, " country files, ", nrow(failures),
                   " failed; tidy with 05_tidy_raw_data.R")
)

message("Registered raw inputs in ", manifest_path)
