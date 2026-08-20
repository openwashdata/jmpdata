# header ------------------------------------------------------------------

# Diff report: per-collection-year data point counts between JMP releases
# Issue: https://github.com/openwashdata/jmpinput/issues/5
# Runs entirely on committed snapshots; no network access is needed.
# Usage: Rscript R/update/06_diff_report.R

# libraries ---------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))

source(here::here("R/update/00_functions.R"))

# configuration -----------------------------------------------------------

report_dir <- here::here("data/derived_data/diff_reports")
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

release_order <- c("jmp2017", "jmp2019", "jmp2021", "jmp2023", "jmp2025")

raw_key <- c("iso3", "source", "type", "year", "var_short")
indicator_key <- c("iso3", "year", "residence", "var_short", "indicator_type")

# snapshot manifest -------------------------------------------------------

## The registry data/derived_data/snapshots_manifest.csv (issue #1; seeded
## by 01_extract_git_history.R, appended to by the tidy scripts) is the
## source of truth. The built-in rows below fill in releases the manifest
## does not know yet, so unavailable releases stay visible in the
## inventory. One row per file; rows whose notes start with "duplicate",
## "alias", "superseded" or "input" (downloaded raw xlsx, not yet tidied)
## are listed in the inventory but excluded from diff chains.

manifest_path <- here::here("data/derived_data/snapshots_manifest.csv")

builtin_manifest <- tribble(
        ~release_id, ~pipeline, ~snapshot_date, ~file,
        "jmp2019", "raw", "2020-09-30",
        "data/derived_data/2020-09-30_jmp_sanitation_raw_data.rds",
        "jmp2021", "raw", "2022-10-19",
        "data/derived_data/2022-10-19_jmp_sanitation_raw_data.csv",
        "jmp2023", "raw", NA,
        "data/derived_data/jmp2023_jmp_sanitation_raw_data.csv",
        "jmp2025", "raw", NA,
        "data/derived_data/jmp2025_jmp_sanitation_raw_data.csv",
        "jmp2017", "indicators", NA,
        "data/derived_data/jmp2017_jmp_washdata_indicators.csv",
        "jmp2019", "indicators", NA,
        "data/derived_data/2020-09-03_jmp_washdata_indicators.csv.gz",
        "jmp2021", "indicators", "2022-10-19",
        "data/derived_data/jmp-washdata-indicators.csv",
        "jmp2023", "indicators", NA,
        "data/derived_data/jmp2023_jmp_washdata_indicators.csv",
        "jmp2025", "indicators", NA,
        "data/derived_data/jmp2025_jmp_washdata_indicators.csv"
    ) |>
    mutate(source = NA_character_, notes = NA_character_)

file_manifest <- if (file.exists(manifest_path)) {
    read_csv(manifest_path, show_col_types = FALSE, col_types = "cccccc")
} else {
    NULL
}

## built-in placeholder rows only fill in release/pipeline combinations
## the manifest does not cover at all

builtin_keep <- if (is.null(file_manifest)) {
    builtin_manifest
} else {
    anti_join(builtin_manifest, file_manifest,
              by = c("release_id", "pipeline"))
}

manifest <- bind_rows(file_manifest, builtin_keep) |>
    distinct(file, .keep_all = TRUE) |>
    mutate(
        available = file.exists(here::here(file)),
        excluded = !is.na(notes) &
            str_detect(notes, "^(duplicate|alias|superseded|input)"),
        release_id = factor(release_id, levels = release_order)
    ) |>
    arrange(pipeline, release_id, snapshot_date)

# diff runners ------------------------------------------------------------

## Pair up the available snapshots of one pipeline in release order, one
## snapshot per release (manifest rows outrank built-in rows, duplicates
## and aliases are already excluded).

consecutive_pairs <- function(manifest, which_pipeline) {

    snapshots <- manifest |>
        filter(pipeline == which_pipeline, available, !excluded) |>
        distinct(release_id, .keep_all = TRUE) |>
        arrange(release_id)

    if (nrow(snapshots) < 2) {
        return(list())
    }

    map(seq_len(nrow(snapshots) - 1), \(i) {
        list(old = snapshots[i, ], new = snapshots[i + 1, ])
    })
}

run_raw_pair <- function(pair) {

    label <- paste0(pair$old$release_id, "_vs_", pair$new$release_id)
    message("Raw diff: ", label)

    diff <- diff_snapshots(
        old = read_raw_snapshot(here::here(pair$old$file)),
        new = read_raw_snapshot(here::here(pair$new$file)),
        key_cols = raw_key,
        value_col = "value",
        labels = paste0(c(pair$old$release_id, pair$new$release_id), "_raw"),
        duplicates_dir = report_dir
    )

    by_year <- summarise_diff_by(diff, "year")
    write_csv(by_year, file.path(
        report_dir, paste0(label, "_raw_by_collection_year.csv")
    ))

    diff |>
        filter(status != "unchanged") |>
        arrange(iso3, year, var_short) |>
        write_csv(file.path(report_dir, paste0(label, "_raw_detail.csv")))

    list(label = label, pair = pair, diff = diff, by_year = by_year)
}

run_indicator_pair <- function(pair) {

    label <- paste0(pair$old$release_id, "_vs_", pair$new$release_id)
    message("Indicator diff: ", label)

    diff <- diff_snapshots(
        old = read_indicator_snapshot(here::here(pair$old$file)),
        new = read_indicator_snapshot(here::here(pair$new$file)),
        key_cols = indicator_key,
        value_col = "percent",
        labels = paste0(c(pair$old$release_id, pair$new$release_id), "_indicators"),
        duplicates_dir = report_dir
    )

    by_year <- summarise_diff_by(diff, "year")
    write_csv(by_year, file.path(
        report_dir, paste0(label, "_indicators_by_year.csv")
    ))

    list(label = label, pair = pair, diff = diff, by_year = by_year)
}

raw_results <- consecutive_pairs(manifest, "raw") |> map(run_raw_pair)
indicator_results <- consecutive_pairs(manifest, "indicators") |> map(run_indicator_pair)

# report ------------------------------------------------------------------

status_totals <- function(diff) {

    tibble(status = c("added", "removed", "changed", "unchanged")) |>
        left_join(count(diff, status), by = "status") |>
        mutate(n = replace_na(n, 0L)) |>
        deframe()
}

headline_lines <- function(result, key_cols) {

    n <- status_totals(result$diff)
    old_rows <- sum(result$diff$status != "added")
    new_rows <- sum(result$diff$status != "removed")

    c(
        paste0(
            "Old snapshot: ", result$pair$old$release_id,
            " (pulled ", result$pair$old$snapshot_date, ", ",
            format(old_rows, big.mark = ","), " data points). ",
            "New snapshot: ", result$pair$new$release_id,
            " (pulled ", result$pair$new$snapshot_date, ", ",
            format(new_rows, big.mark = ","), " data points)."
        ),
        "",
        paste0(
            "Compared on the identity key `",
            paste(key_cols, collapse = " + "), "`: **",
            format(n["added"], big.mark = ","), " added**, ",
            format(n["removed"], big.mark = ","), " removed, ",
            format(n["changed"], big.mark = ","), " changed, ",
            format(n["unchanged"], big.mark = ","), " unchanged."
        )
    )
}

raw_section <- function(result) {

    top_added <- result$diff |>
        filter(status == "added") |>
        count(iso3, name = "n_added") |>
        arrange(desc(n_added), iso3) |>
        slice_head(n = 15)

    c(
        paste0("### ", str_replace(result$label, "_vs_", " vs "), " (raw survey data)"),
        "",
        headline_lines(result, raw_key),
        "",
        "#### Data points by collection year",
        "",
        md_table(result$by_year),
        "",
        "#### Top 15 countries by added data points",
        "",
        md_table(top_added),
        ""
    )
}

indicator_section <- function(result) {

    c(
        paste0("### ", str_replace(result$label, "_vs_", " vs "), " (indicator estimates)"),
        "",
        headline_lines(result, indicator_key),
        "",
        "#### Data points by estimate year",
        "",
        md_table(result$by_year),
        ""
    )
}

no_pair_lines <- function(which_pipeline) {

    available <- manifest |>
        filter(pipeline == which_pipeline, available, !excluded) |>
        distinct(release_id) |>
        pull(release_id)

    paste0(
        "Fewer than two ", which_pipeline,
        " snapshots are available (currently: ",
        if (length(available) == 0) "none" else paste(available, collapse = ", "),
        "), so there is no consecutive release pair to diff yet. ",
        "See the snapshot inventory above and issues #1, #2 and #4."
    )
}

inventory <- manifest |>
    mutate(available = ifelse(available, "yes", "no")) |>
    select(release_id, pipeline, snapshot_date, file, source,
           available, notes)

unavailable <- manifest |>
    filter(!available) |>
    distinct(release_id, pipeline)

lines <- c(
    "# JMP snapshot diff report",
    "",
    paste0(
        "Generated on ", Sys.Date(),
        " by `R/update/06_diff_report.R` ",
        "([issue #5](https://github.com/openwashdata/jmpinput/issues/5)). ",
        "All numbers come from committed snapshots; no network access is used. ",
        "The CSV files next to this report are the machine-readable source of ",
        "truth; this file is the human summary."
    ),
    "",
    "## Snapshot inventory",
    "",
    md_table(inventory),
    ""
)

if (nrow(unavailable) > 0) {
    lines <- c(
        lines,
        paste0(
            "Not yet available: ",
            paste0(unavailable$release_id, " (", unavailable$pipeline, ")",
                   collapse = ", "),
            ". Recovery of historic releases is tracked in issue #2, the fresh ",
            "jmp2025 download in issue #4, and the snapshot registry in issue #1."
        ),
        ""
    )
}

lines <- c(lines, "## Raw survey data (sanitation)", "")

if (length(raw_results) == 0) {
    lines <- c(lines, no_pair_lines("raw"), "")
} else {
    lines <- c(lines, flatten_chr(map(raw_results, raw_section)))
}

lines <- c(lines, "## Modelled indicator estimates", "")

if (length(indicator_results) == 0) {
    lines <- c(lines, no_pair_lines("indicators"), "")
} else {
    lines <- c(lines, flatten_chr(map(indicator_results, indicator_section)))
}

lines <- c(
    lines,
    "## Caveats",
    "",
    paste0(
        "- A `changed` data point is not necessarily a corrected value: every ",
        "JMP release re-models the entire 2000 to present series, so `changed` ",
        "counts include expected model re-estimation of historical years. This ",
        "applies above all to the indicator estimates."
    ),
    paste0(
        "- The `added` counts per collection year answer questions like \"how ",
        "many survey data points with collection year 2019 did the newer ",
        "release add\"."
    ),
    paste0(
        "- Raw snapshots are normalized before diffing: the 2020-09-30 pull ",
        "suffixes sources with a two-digit publication year (\"CEN00\") which ",
        "later pulls drop (\"CEN\"), so trailing digits are stripped; type ",
        "labels are mapped to English base categories (the 2022 pull split ",
        "\"Survey with microdata\" out of \"Survey\", the 2025 release ",
        "localizes types into the country language); and the 2025 variable ",
        "renames are mapped back to the legacy vocabulary (suffix _t to _n, ",
        "s_ns_* to s_od_*, verified value-identical on matched keys). ",
        "Without this normalization not a single identity key matches ",
        "across releases. Renames that go beyond these rules still appear ",
        "as a paired `added` and `removed` row."
    ),
    paste0(
        "- Where two source editions collapse onto one normalized key with ",
        "conflicting values (Poland \"ES12\"/\"ES13\", four data points), ",
        "the newest edition is kept."
    ),
    paste0(
        "- `data/derived_data/2022-10-18_jmp_sanitation_raw_data.csv` is ",
        "byte-identical to the 2022-10-19 file and is treated as a duplicate, ",
        "not a separate snapshot."
    ),
    paste0(
        "- Release labels follow the JMP publication held at pull time: the ",
        "2020-09-30 pull predates the JMP 2021 update and therefore holds the ",
        "JMP 2019 release; the 2022-10-19 pull holds the JMP 2021 release."
    ),
    paste0(
        "- Tidy indicator snapshots are normalized to the legacy variable ",
        "vocabulary at tidy time (the JMP 2023/2025 world files renamed ",
        "most variables, e.g. wat_basal for wat_bas, san_ns for san_od, ",
        "suffix _t for _n), so var_short is comparable across releases in ",
        "the indicator diffs."
    ),
    paste0(
        "- Countries without any data are stored as all-NA placeholder rows ",
        "in the raw snapshots; they are dropped before diffing."
    ),
    ""
)

writeLines(lines, file.path(report_dir, "diff_report.md"))

message("Report written to ", file.path(report_dir, "diff_report.md"))
