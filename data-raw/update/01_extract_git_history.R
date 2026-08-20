# header ------------------------------------------------------------------

# Snapshot registry and historic baselines from this repo's git history.
# Issue: https://github.com/openwashdata/jmpdata/issues/1
#
# Runs offline (no network) and is idempotent: every step checks whether
# its output already exists. It
#
#   1. stages the jmp2019-era world file from commit a04e8bb into the
#      gitignored data-raw/raw_data/snapshots/jmp2019/,
#   2. writes a one-time dated gzip copy of the current (jmp2021)
#      indicators file, byte-identical under the gzip,
#   3. seeds data-raw/derived_data/snapshots_manifest.csv with every snapshot
#      the repo currently holds,
#   4. re-derives the jmp2019 indicators from the staged world file with
#      the parameterized tidy pipeline (04_tidy_indicators.R), preferred
#      over extracting the old derived CSV at c943c50 because the result
#      is schema-consistent with the other releases.
#
# Usage: Rscript data-raw/update/01_extract_git_history.R

# libraries ---------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))

source(here::here("data-raw/update/00_functions.R"))

derived_dir <- here::here("data-raw/derived_data")
manifest_path <- file.path(derived_dir, "snapshots_manifest.csv")

# 1. stage the jmp2019 world file from git history --------------------------

## a04e8bb (2020-09-03) is the last commit whose data/raw_data/WLD.xlsx is
## the JMP 2019 release; 3e14fd1 (2022-10-19) overwrote it with jmp2021

jmp2019_commit <- "a04e8bb"
jmp2019_date <- "2020-09-03"
jmp2019_dir <- here::here("data-raw/raw_data/snapshots/jmp2019")
jmp2019_wld <- file.path(jmp2019_dir, "WLD.xlsx")

dir.create(jmp2019_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(jmp2019_wld)) {
    status <- system2(
        "git", c("show", paste0(jmp2019_commit, ":data/raw_data/WLD.xlsx")),
        stdout = jmp2019_wld
    )
    if (status != 0 || file.size(jmp2019_wld) == 0) {
        unlink(jmp2019_wld)
        stop("git show failed for ", jmp2019_commit,
             ":data/raw_data/WLD.xlsx", call. = FALSE)
    }
    message("Staged jmp2019 world file: ", jmp2019_wld,
            " (", file.size(jmp2019_wld), " bytes)")
} else {
    message("jmp2019 world file already staged, skipping")
}

# 2. dated gzip copy of the jmp2021 indicators ------------------------------

## byte-level gzip of the committed file, so the copy is exact; future
## indicator snapshots follow this dated-gzip convention while the undated
## jmp-washdata-indicators.csv continues to be overwritten as "latest"

indicators_latest <- file.path(derived_dir, "jmp-washdata-indicators.csv")
indicators_dated <- file.path(
    derived_dir, "2022-10-19_jmp-washdata-indicators.csv.gz"
)

if (!file.exists(indicators_dated)) {
    con <- gzfile(indicators_dated, "wb")
    writeBin(readBin(indicators_latest, "raw",
                     file.size(indicators_latest)), con)
    close(con)
    message("Written dated copy: ", indicators_dated)
} else {
    message("Dated jmp2021 indicators copy already exists, skipping")
}

# 3. seed the manifest ------------------------------------------------------

## every snapshot the repo currently holds, with release attribution;
## rows whose notes start with duplicate/alias/superseded stay listed but
## are excluded from diff chains by 06_diff_report.R

seed <- function(...) {
    append_manifest_row(manifest_path, ...)
}

seed("jmp2019", "raw", "2020-09-03",
     "data-raw/derived_data/2020-09-03_jmp_sanitation_raw_data.rds", "live",
     "superseded by the 2020-09-30 pull")
seed("jmp2019", "raw", "2020-09-30",
     "data-raw/derived_data/2020-09-30_jmp_sanitation_raw_data.rds", "live",
     "jmp2019-era raw baseline, as served 2020-09")
seed("jmp2021", "raw", "2022-10-18",
     "data-raw/derived_data/2022-10-18_jmp_sanitation_raw_data.csv", "live",
     "duplicate of the 2022-10-19 csv (byte-identical)")
seed("jmp2021", "raw", "2022-10-18",
     "data-raw/derived_data/2022-10-18_jmp_sanitation_raw_data.rds", "live",
     "duplicate of the 2022-10-19 rds (byte-identical)")
seed("jmp2021", "raw", "2022-10-19",
     "data-raw/derived_data/2022-10-19_jmp_sanitation_raw_data.csv", "live",
     "jmp2021 raw baseline")
seed("jmp2021", "raw", "2022-10-19",
     "data-raw/derived_data/2022-10-19_jmp_sanitation_raw_data.rds", "live",
     "alias of the 2022-10-19 csv (same data, rds format)")
seed("jmp2021", "indicators", "2022-10-19",
     "data-raw/derived_data/2022-10-19_jmp-washdata-indicators.csv.gz", "live",
     "jmp2021 indicators baseline; dated gzip copy of the file at commit 782603b")
seed("jmp2021", "indicators", "2022-10-19",
     "data-raw/derived_data/jmp-washdata-indicators.csv", "live",
     "alias: undated latest, overwritten by each release")

message("Manifest seeded: ", manifest_path)

# 4. re-derive the jmp2019 indicators ---------------------------------------

jmp2019_indicators <- file.path(
    derived_dir, paste0(jmp2019_date, "_jmp_washdata_indicators.csv.gz")
)

if (!file.exists(jmp2019_indicators)) {

    message("Re-deriving jmp2019 indicators with 04_tidy_indicators.R")

    env_vars <- c(
        JMP_RELEASE_ID = "jmp2019",
        JMP_SNAPSHOT_DIR = "data-raw/raw_data/snapshots/jmp2019",
        JMP_PULL_DATE = jmp2019_date,
        JMP_SOURCE = "git-history",
        JMP_OUTPUT_COMPRESS = "true"
    )

    do.call(Sys.setenv, as.list(env_vars))
    on.exit(Sys.unsetenv(names(env_vars)), add = TRUE)

    source(here::here("data-raw/update/04_tidy_indicators.R"))

} else {
    message("jmp2019 indicators already derived, skipping")
}

message("Done. Snapshots registered: ",
        nrow(read_csv(manifest_path, show_col_types = FALSE)))
