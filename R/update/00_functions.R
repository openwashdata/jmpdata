# header ------------------------------------------------------------------

# Shared functions for the JMP data update pipeline (R/update/)
# Issue: https://github.com/openwashdata/jmpinput/issues/5
# The legacy R/gather/ scripts stay untouched as the historical record;
# new work lives in R/update/.

# diff engine -------------------------------------------------------------

## Compare two snapshots of the same dataset on an identity key and classify
## every data point:
##
##   added     key present in the newer snapshot only
##   removed   key present in the older snapshot only
##   changed   key in both, values differ by more than tol or exactly one is NA
##   unchanged otherwise
##
## old, new        data frames holding the older and newer snapshot
## key_cols        character vector of columns identifying one data point
## value_col       single column holding the measured value
## tol             numeric tolerance below which two values count as equal
## labels          snapshot labels used in messages and duplicate file names
## duplicates_dir  if set, non-unique keys are written there before stopping

diff_snapshots <- function(old, new, key_cols, value_col, tol = 1e-6,
                           labels = c("old", "new"), duplicates_dir = NULL) {

    stop_if_duplicate_keys(old, key_cols, labels[1], duplicates_dir)
    stop_if_duplicate_keys(new, key_cols, labels[2], duplicates_dir)

    old_keyed <- old |>
        select(all_of(c(key_cols, value_col))) |>
        rename(value_old = all_of(value_col)) |>
        mutate(.in_old = TRUE)

    new_keyed <- new |>
        select(all_of(c(key_cols, value_col))) |>
        rename(value_new = all_of(value_col)) |>
        mutate(.in_new = TRUE)

    full_join(old_keyed, new_keyed, by = key_cols) |>
        mutate(
            .in_old = !is.na(.in_old),
            .in_new = !is.na(.in_new),
            status = case_when(
                !.in_old ~ "added",
                !.in_new ~ "removed",
                xor(is.na(value_old), is.na(value_new)) ~ "changed",
                !is.na(value_old) & abs(value_new - value_old) > tol ~ "changed",
                TRUE ~ "unchanged"
            )
        ) |>
        select(all_of(key_cols), value_old, value_new, status)
}

stop_if_duplicate_keys <- function(data, key_cols, label, duplicates_dir = NULL) {

    duplicates <- data |>
        count(across(all_of(key_cols)), name = "n_rows") |>
        filter(n_rows > 1)

    if (nrow(duplicates) == 0) {
        return(invisible(data))
    }

    if (!is.null(duplicates_dir)) {
        dir.create(duplicates_dir, recursive = TRUE, showWarnings = FALSE)
        duplicates_path <- file.path(
            duplicates_dir, paste0("duplicate_keys_", label, ".csv")
        )
        write_csv(duplicates, duplicates_path)
        stop("Identity key is not unique in snapshot '", label, "': ",
             nrow(duplicates), " duplicated keys, written to ",
             duplicates_path, call. = FALSE)
    }

    stop("Identity key is not unique in snapshot '", label, "': ",
         nrow(duplicates), " duplicated keys", call. = FALSE)
}

## Count data points per status within groups, e.g. per collection year.
## Always returns all four n_* columns, even when a status never occurs.

summarise_diff_by <- function(diff, by) {

    counts <- diff |>
        count(across(all_of(by)), status) |>
        pivot_wider(names_from = status, values_from = n,
                    values_fill = 0, names_prefix = "n_")

    for (col in c("n_added", "n_removed", "n_changed", "n_unchanged")) {
        if (!col %in% names(counts)) {
            counts[[col]] <- 0L
        }
    }

    counts |>
        select(all_of(by), n_added, n_removed, n_changed, n_unchanged) |>
        arrange(across(all_of(by)))
}

# snapshot readers --------------------------------------------------------

## Raw survey data (gather_raw_data.R lineage). Countries without any data
## are stored as all-NA placeholder rows; those are not data points and are
## dropped before diffing. residence, san_service_chain and var_long are
## functions of var_short and excluded from the identity key.
##
## The identity key is not stable across releases without normalization:
## the 2020-09-30 pull suffixes sources with a two-digit publication year
## ("CEN00") which the 2022-10-19 pull drops ("CEN"), and the old "Survey"
## type was split into "Survey" and "Survey with microdata". Without
## normalization not a single key matches across those two releases.
## normalize = TRUE strips the suffix and collapses the type split. Where
## two source editions collapse onto the same key with conflicting values
## (Poland "ES12"/"ES13"), the newest edition is kept and a message
## reports how many rows were dropped.

read_raw_snapshot <- function(path, normalize = TRUE) {

    data <- if (tolower(tools::file_ext(path)) == "rds") {
        readRDS(path)
    } else {
        read_csv(path, show_col_types = FALSE)
    }

    data <- data |>
        as_tibble() |>
        filter(!(is.na(source) & is.na(type) & is.na(year) &
                     is.na(var_short) & is.na(value))) |>
        transmute(
            iso3 = as.character(iso3),
            source = as.character(source),
            type = as.character(type),
            year = as.integer(year),
            var_short = as.character(var_short),
            value = as.double(value)
        )

    if (!normalize) {
        return(data)
    }

    normalized <- data |>
        mutate(
            source_edition = source,
            source = str_remove(source, "[0-9]+$"),
            type = if_else(type == "Survey with microdata", "Survey", type)
        ) |>
        arrange(desc(source_edition)) |>
        distinct(iso3, source, type, year, var_short, .keep_all = TRUE) |>
        select(-source_edition) |>
        arrange(iso3, year, var_short)

    n_dropped <- nrow(data) - nrow(normalized)
    if (n_dropped > 0) {
        message("read_raw_snapshot: ", basename(path), ": dropped ",
                n_dropped, " rows whose keys collapse under source ",
                "normalization; kept the newest source edition")
    }

    normalized
}

## Modelled indicator estimates (gather_jmp_data.R lineage). indicator_type
## is part of the identity key because the enrichment pivot can emit one row
## per matching type for the same var_short.

read_indicator_snapshot <- function(path) {

    read_csv(path, show_col_types = FALSE, guess_max = 100000) |>
        transmute(
            iso3 = as.character(iso3),
            year = as.integer(year),
            residence = as.character(residence),
            var_short = as.character(var_short),
            indicator_type = as.character(indicator_type),
            percent = as.double(percent)
        )
}

# markdown helpers --------------------------------------------------------

## Render a data frame as a GitHub-flavoured markdown table without adding
## a dependency on knitr.

md_table <- function(data) {

    cells <- data |>
        mutate(across(everything(), \(x) {
            ifelse(is.na(x), "", format(x, trim = TRUE, scientific = FALSE))
        }))

    header <- paste0("| ", paste(names(cells), collapse = " | "), " |")
    separator <- paste0("|", paste(rep("---", ncol(cells)), collapse = "|"), "|")

    if (nrow(cells) == 0) {
        return(c(header, separator))
    }

    rows <- apply(cells, 1, \(row) paste0("| ", paste(row, collapse = " | "), " |"))

    c(header, separator, rows)
}
