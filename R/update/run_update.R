# header ------------------------------------------------------------------

# One-command orchestrator for the JMP data update: runs the pipeline
# steps 01 to 06 in order, driven by the parameters below.
# Issue: https://github.com/openwashdata/jmpinput/issues/6
# See docs/UPDATING.md for the step-by-step version and prerequisites.
#
# Usage: edit the parameters, then
#   Rscript R/update/run_update.R
#
# Network steps are off by default; they must run on a local machine
# (remote sandbox sessions cannot reach washdata.org or archive.org).

# libraries ---------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))

source(here::here("R/update/00_functions.R"))

# parameters ---------------------------------------------------------------

## offline: stage git-history baselines and seed the manifest (idempotent)
run_extract_git_history <- TRUE

## network (archive.org): recover historic world files via Wayback
run_recover_archives <- FALSE

## network (washdata.org): download the current release (resumable)
run_download_current <- FALSE

## releases to tidy; snapshot_date NA means today. The jmp2023 row stays
## commented until issue #9 (variable lookup extension) lands: its world
## file uses the renamed vocabulary and 04 stops on it by design.
tidy_releases <- tribble(
    ~release_id, ~snapshot_date, ~source,
    "jmp2025", NA_character_, "live"
    # , "jmp2023", "2024-05-20", "wayback"
)

## regenerate the diff report at the end (offline)
run_diff_report <- TRUE

# helpers ------------------------------------------------------------------

## source one pipeline script with a temporary set of JMP_* environment
## variables; a failure (e.g. the unmatched-variables stop in 04) is
## reported and the run continues with the next step

run_step <- function(script, env = character()) {

    if (length(env) > 0) {
        do.call(Sys.setenv, as.list(env))
        on.exit(Sys.unsetenv(names(env)), add = TRUE)
    }

    message("\n==== ", script, if (length(env) > 0) {
        paste0(" [", paste(names(env), env, sep = "=", collapse = " "), "]")
    }, " ====")

    tryCatch(
        source(here::here("R/update", script)),
        error = \(e) message("FAILED (continuing): ", conditionMessage(e))
    )

    invisible(NULL)
}

# run ----------------------------------------------------------------------

if (run_extract_git_history) {
    run_step("01_extract_git_history.R")
}

if (run_recover_archives) {
    run_step("02_recover_archives.R")
}

if (run_download_current) {
    run_step("03_download_current.R")
}

for (i in seq_len(nrow(tidy_releases))) {

    release <- tidy_releases$release_id[i]
    snapshot_dir <- here::here("data/raw_data/snapshots", release)

    env <- c(
        JMP_RELEASE_ID = release,
        JMP_SOURCE = tidy_releases$source[i]
    )
    if (!is.na(tidy_releases$snapshot_date[i])) {
        env["JMP_PULL_DATE"] <- tidy_releases$snapshot_date[i]
    }

    if (dir.exists(file.path(snapshot_dir, "country_files"))) {
        run_step("05_tidy_raw_data.R", env)
    } else {
        message(release, ": no country_files under ", snapshot_dir,
                ", skipping raw tidy")
    }

    if (file.exists(file.path(snapshot_dir, "WLD.xlsx"))) {
        run_step("04_tidy_indicators.R",
                 c(env, JMP_OUTPUT_COMPRESS = "true"))
    } else {
        message(release, ": no WLD.xlsx under ", snapshot_dir,
                ", skipping indicators tidy")
    }
}

if (run_diff_report) {
    run_step("06_diff_report.R")
}

message("\nUpdate run finished. See data/derived_data/diff_reports/ and ",
        "data/derived_data/snapshots_manifest.csv.")
