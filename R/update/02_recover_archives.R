# header ------------------------------------------------------------------

# Recover historic JMP releases from the Wayback Machine.
# Issue: https://github.com/openwashdata/jmpinput/issues/2
#
# washdata.org only serves the latest release, so the jmp2017 baseline and
# the jmp2023 update are recovered from web.archive.org captures. The
# preferred source (WASHNote/jmpwashdata git history) was inspected first
# and holds no raw xlsx in any revision; its newest packaged data is the
# JMP 2021 release pulled 2023-01-15.
#
# For each target release the script queries the CDX index for captures of
# the world-file download URL inside the release window, fetches original
# bytes via the id_ URL form (avoiding Wayback-rewritten responses),
# validates the result (xlsx magic bytes, readable wat sheet, max
# estimate year matching the release) and stages it under gitignored
# data/raw_data/snapshots/<release_id>/. Outcomes, including failures with
# their evidence, are recorded in snapshots_manifest.csv (source =
# wayback, "input:" notes so they never enter diff chains untidied).
#
# Raw country files are only recovered complete or not at all: a partial
# snapshot corrupts added/removed counts. A capped probe (first 20
# countries) stops early when archive coverage is below 50 percent.
#
# Idempotent; must run on a machine that can reach web.archive.org.
# Usage: Rscript R/update/02_recover_archives.R

# libraries ---------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))

source(here::here("R/update/00_functions.R"))

options(timeout = 600)

## pause between archive.org requests, in seconds
pacing <- 1

manifest_path <- here::here("data/derived_data/snapshots_manifest.csv")

## release windows: from first publication of the release to just before
## the next release replaced it on washdata.org

targets <- tribble(
    ~release_id, ~from, ~to, ~expected_max_year,
    "jmp2017", "20170712", "20190617", 2015,
    "jmp2023", "20230706", "20250601", 2022
)

# wayback helpers ----------------------------------------------------------

cdx_captures <- function(url, from, to) {

    query <- paste0(
        "https://web.archive.org/cdx/search/cdx?url=",
        utils::URLencode(url, reserved = TRUE),
        "&from=", from, "&to=", to, "&output=json"
    )

    raw <- tryCatch(jsonlite::fromJSON(query), error = \(e) NULL)

    if (is.null(raw) || length(raw) < 2) {
        return(tibble())
    }

    raw[-1, , drop = FALSE] |>
        as_tibble(.name_repair = "minimal") |>
        set_names(raw[1, ])
}

## fetch the original bytes of a capture; the id_ suffix is required to
## avoid Wayback-rewritten responses. Redirect chains (the download URL
## 302s to the actual file) are followed inside the archive.

fetch_wayback <- function(timestamp, original, dest) {

    url <- paste0("https://web.archive.org/web/", timestamp, "id_/", original)

    status <- tryCatch(
        suppressWarnings(download.file(url, destfile = dest, mode = "wb",
                                       quiet = TRUE)),
        error = \(e) -1L
    )

    if (!identical(status, 0L) || !is_xlsx(dest)) {
        unlink(dest)
        return(FALSE)
    }

    TRUE
}

validate_world_file <- function(path, expected_max_year) {

    sheets <- tryCatch(readxl::excel_sheets(path), error = \(e) character())
    wat_sheet <- intersect(c("wat", "Water Data"), sheets)

    if (length(wat_sheet) == 0) {
        return(list(ok = FALSE, reason = "no wat sheet"))
    }

    data <- tryCatch(
        readxl::read_excel(path, sheet = wat_sheet[1]),
        error = \(e) NULL
    )

    if (is.null(data) || !"year" %in% names(data)) {
        return(list(ok = FALSE, reason = "wat sheet unreadable"))
    }

    max_year <- suppressWarnings(as.integer(max(data$year, na.rm = TRUE)))

    if (!identical(max_year, as.integer(expected_max_year))) {
        return(list(ok = FALSE, reason = paste0(
            "stale capture: max year ", max_year,
            ", expected ", expected_max_year
        )))
    }

    list(ok = TRUE, reason = paste0("max estimate year ", max_year))
}

# world file recovery -------------------------------------------------------

recover_world_file <- function(release_id, from, to, expected_max_year) {

    snapshot_dir <- here::here("data/raw_data/snapshots", release_id)
    wld_path <- file.path(snapshot_dir, "WLD.xlsx")
    manifest_file <- file.path("data/raw_data/snapshots", release_id,
                               "WLD.xlsx")

    if (is_xlsx(wld_path)) {
        message(release_id, ": world file already staged, skipping")
        return(TRUE)
    }

    captures <- cdx_captures("washdata.org/data/country/WLD/download",
                             from, to)
    Sys.sleep(pacing)

    message(release_id, ": ", nrow(captures),
            " Wayback capture(s) of the world file URL in ", from, "-", to)

    verdicts <- character()

    for (i in seq_len(nrow(captures))) {

        ts <- captures$timestamp[i]
        original <- captures$original[i]
        candidate <- tempfile(fileext = ".xlsx")

        if (!fetch_wayback(ts, original, candidate)) {
            verdicts <- c(verdicts, paste0(ts, ": fetch failed"))
            Sys.sleep(pacing)
            next
        }

        verdict <- validate_world_file(candidate, expected_max_year)
        verdicts <- c(verdicts, paste0(ts, ": ", verdict$reason))

        if (verdict$ok) {
            dir.create(snapshot_dir, recursive = TRUE, showWarnings = FALSE)
            file.copy(candidate, wld_path)
            unlink(candidate)
            message(release_id, ": recovered from capture ", ts, " (",
                    verdict$reason, "), staged at ", wld_path)
            append_manifest_row(
                manifest_path,
                release_id = release_id,
                pipeline = "indicators",
                snapshot_date = paste0(substr(ts, 1, 4), "-",
                                       substr(ts, 5, 6), "-",
                                       substr(ts, 7, 8)),
                file = manifest_file,
                source = "wayback",
                notes = paste0("input: world file from Wayback capture ",
                               ts, " of ", original, ", ", verdict$reason,
                               "; tidy with 04_tidy_indicators.R")
            )
            return(TRUE)
        }

        unlink(candidate)
        Sys.sleep(pacing)
    }

    evidence <- if (nrow(captures) == 0) {
        paste0("no Wayback captures of the world file URL between ",
               from, " and ", to)
    } else {
        paste0("no valid capture: ", paste(verdicts, collapse = "; "))
    }

    message(release_id, ": world file NOT recovered (", evidence, ")")

    append_manifest_row(
        manifest_path,
        release_id = release_id,
        pipeline = "indicators",
        snapshot_date = NA_character_,
        file = manifest_file,
        source = "wayback",
        notes = paste0("input: not recovered; ", evidence)
    )

    FALSE
}

# country file coverage probe ------------------------------------------------

## Raw snapshots are all-or-nothing. The probe checks archive coverage for
## the first probe_cap countries and stops early below 50 percent; even
## with promising coverage, downloading only happens when every country
## file is archived.

probe_country_files <- function(release_id, from, to, probe_cap = 20) {

    wld_path <- here::here("data/raw_data/snapshots", release_id, "WLD.xlsx")

    if (!is_xlsx(wld_path)) {
        message(release_id, ": no world file, skipping country probe")
        return(invisible(NULL))
    }

    iso3s <- read_jmp_sheet(wld_path, c("wat", "Water Data"),
                            reader = "readxl") |>
        distinct(iso3) |>
        pull(iso3)

    probe <- head(iso3s, probe_cap)
    archived <- logical(length(probe))

    for (i in seq_along(probe)) {
        captures <- cdx_captures(
            paste0("washdata.org/data/country/", probe[i], "/download"),
            from, to
        )
        archived[i] <- nrow(captures) > 0
        Sys.sleep(pacing)
    }

    coverage <- sum(archived)
    message(release_id, ": country file archive coverage ", coverage, "/",
            length(probe), " in the first ", length(probe), " of ",
            length(iso3s), " countries")

    if (coverage < length(probe) / 2) {
        note <- paste0("input: raw country files not recovered (", coverage,
                       "/", length(probe), " of the first ", length(probe),
                       " countries archived ", from, "-", to,
                       "; a partial snapshot would corrupt added/removed ",
                       "counts)")
    } else {
        note <- paste0("input: raw country files not recovered; probe found ",
                       coverage, "/", length(probe),
                       " archived, full recovery of all ", length(iso3s),
                       " countries not attempted in this run")
    }

    append_manifest_row(
        manifest_path,
        release_id = release_id,
        pipeline = "raw",
        snapshot_date = NA_character_,
        file = file.path("data/raw_data/snapshots", release_id,
                         "country_files"),
        source = "wayback",
        notes = note
    )

    invisible(NULL)
}

# run ------------------------------------------------------------------------

for (i in seq_len(nrow(targets))) {
    recovered <- recover_world_file(
        targets$release_id[i], targets$from[i], targets$to[i],
        targets$expected_max_year[i]
    )
    if (recovered) {
        probe_country_files(targets$release_id[i],
                            targets$from[i], targets$to[i])
    }
}

message("Done. See ", manifest_path, " for outcomes.")
