# header ------------------------------------------------------------------

# Shared functions for the JMP data update pipeline (data-raw/update/)
# Issue: https://github.com/openwashdata/jmpdata/issues/5
# The legacy data-raw/gather/ scripts stay untouched as the historical record;
# new work lives in data-raw/update/.

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

# residence from variable code ---------------------------------------------

## Residence level from the suffix of a JMP short variable code. The
## patterns are anchored at the end, so a stem that contains _n, _r or _u
## (for example s_lat_nemp_u, s_sew_rtp_t) cannot match the wrong level.
## _t (total, 2025 vocabulary) and _n (national, older releases) are both
## national. Codes without a recognised suffix and NA give NA.

derive_residence <- function(var_short) {
    dplyr::case_when(
        stringr::str_detect(var_short, "_(t|n)$") ~ "national",
        stringr::str_detect(var_short, "_r$") ~ "rural",
        stringr::str_detect(var_short, "_u$") ~ "urban"
    )
}

# update pipeline parameters ----------------------------------------------

## Shared parameter block for the tidy scripts (04, 05). Everything is set
## via environment variables so the same scripts tidy any release:
##
##   JMP_RELEASE_ID   release being tidied (default "jmp2025")
##   JMP_SNAPSHOT_DIR directory holding the downloaded files for the release
##                    (default data-raw/raw_data/snapshots/<release_id>)
##   JMP_OUTPUT_DIR   where tidy outputs and the manifest go
##                    (default data-raw/derived_data)
##   JMP_PULL_DATE    download date used to prefix output files
##                    (default today; set to 2022-10-19 when re-tidying the
##                    committed 2022 pull)

jmp_update_params <- function() {

    release_id <- Sys.getenv("JMP_RELEASE_ID", "jmp2025")

    snapshot_dir <- Sys.getenv(
        "JMP_SNAPSHOT_DIR",
        file.path("data-raw/raw_data/snapshots", release_id)
    )
    output_dir <- Sys.getenv("JMP_OUTPUT_DIR", "data-raw/derived_data")

    ## relative paths resolve against the repo root; absolute paths pass
    ## through (here::here() would mangle them). output_dir_label keeps the
    ## unresolved string for the manifest's path column, so repo-relative
    ## outputs stay relative there.
    resolve <- function(path) {
        if (startsWith(path, "/")) path else here::here(path)
    }

    list(
        release_id = release_id,
        snapshot_dir = resolve(snapshot_dir),
        snapshot_dir_label = snapshot_dir,
        output_dir = resolve(output_dir),
        output_dir_label = output_dir,
        pull_date = Sys.getenv("JMP_PULL_DATE", as.character(Sys.Date())),
        ## provenance of the raw input, recorded in the manifest:
        ## live | wayback | git-history | jmpwashdata
        source = Sys.getenv("JMP_SOURCE", "live"),
        ## write dated outputs as .csv.gz (used for the large indicator
        ## snapshots that get committed)
        compress = tolower(Sys.getenv("JMP_OUTPUT_COMPRESS", "false")) == "true"
    )
}

# excel readers ------------------------------------------------------------

## Read one sheet from a JMP Excel file by name, never by position: the
## positional indices 3/5/7 of the legacy scripts would silently break if
## JMP reorders sheets. sheet_name can be a vector of candidates because
## JMP renamed the data sheets between releases (2020 world file: "Water
## Data" / "Sanitation Data" / "Hygiene Data"; 2022 world file: "wat" /
## "san" / "hyg"); the first candidate present is used. The reader
## argument preserves the exact reader the legacy pipeline used (openxlsx
## for the world file, readxl for country files), because the two guess
## column types differently and the outputs must stay comparable.

read_jmp_sheet <- function(path, sheet_name,
                           reader = c("openxlsx", "readxl"), ...) {

    reader <- match.arg(reader)

    sheets <- if (reader == "openxlsx") {
        openxlsx::getSheetNames(path)
    } else {
        readxl::excel_sheets(path)
    }

    matched <- intersect(sheet_name, sheets)

    if (length(matched) == 0) {
        stop("None of the sheet(s) ",
             paste0("'", sheet_name, "'", collapse = ", "),
             " found in ", basename(path),
             ". Available sheets: ", paste(sheets, collapse = ", "),
             call. = FALSE)
    }

    if (reader == "openxlsx") {
        as_tibble(openxlsx::read.xlsx(path, sheet = matched[1], ...))
    } else {
        readxl::read_excel(path, sheet = matched[1], ...)
    }
}

# variable lookup join -----------------------------------------------------

## Map the 2025 world-file vocabulary onto the legacy one before the
## lookup join (issue #9): the JMP 2025 release renamed the national
## suffix _n to _t and most variable stems. Mapping the names, rather
## than duplicating 53 lookup rows under new names, keeps the hand-curated
## labels authoritative and makes tidy indicator snapshots
## schema-consistent across releases, which the diff engine requires.
## Legacy names pass through untouched (all rules are anchored), so
## re-tidying the 2019/2022 world files is a no-op. The renames were
## reviewed and confirmed on issue #9; s_ns/s_od equivalence is verified
## value-identical in the raw data.

normalize_indicator_vars <- function(var_short) {

    var_short |>
        str_replace("_t$", "_n") |>
        str_replace("^arc_wat_basal", "arc_wat_bas") |>
        str_replace("^arc_san_basal", "arc_san_bas") |>
        str_replace("^arc_san_ns_", "arc_san_od_") |>
        str_replace("^wat_basal", "wat_bas") |>
        str_replace("^san_basal", "san_bas") |>
        str_replace("^wat_ns_", "wat_sur_") |>
        str_replace("^san_ns_", "san_od_") |>
        str_replace("^hyg_ns_", "hyg_nfac_") |>
        str_replace("^wat_imp_prem", "wat_premises") |>
        str_replace("^wat_imp_av", "wat_available") |>
        str_replace("^wat_imp_qual", "wat_quality") |>
        str_replace("^wat_imp_npip", "wat_npip") |>
        str_replace("^san_othimp", "san_lat") |>
        str_replace("^wat_arc_sm", "arc_wat_sm") |>
        str_replace("^san_arc_sm", "arc_san_sm")
}

## Left-join the hand-curated variable lookup, then warn about and record
## any var_short the lookup does not know BEFORE dropping it. New JMP
## releases are expected to introduce variables; the warning file is the
## signal to hand-extend the lookup and re-run. This replaces the legacy
## silent filter(!is.na(var_long)).

join_jmp_vars <- function(data, lookup,
                          output_dir = "data-raw/derived_data",
                          pull_date = as.character(Sys.Date())) {

    joined <- data |>
        left_join(lookup, by = "var_short")

    unmatched <- joined |>
        filter(is.na(var_long)) |>
        distinct(var_short)

    if (nrow(unmatched) > 0) {
        unmatched_path <- file.path(
            output_dir, paste0(pull_date, "_unmatched_variables.csv")
        )
        write_csv(unmatched, unmatched_path)

        n_vars <- n_distinct(data$var_short)

        ## a few unknown variables are expected in a new release; a lookup
        ## that knows less than half the file signals a vocabulary change
        ## that needs hand-curation, not a quietly gutted output
        if (nrow(unmatched) > n_vars / 2) {
            stop("The variable lookup knows only ",
                 n_vars - nrow(unmatched), " of ", n_vars,
                 " var_short values in this snapshot; the release ",
                 "vocabulary has changed. Unmatched list written to ",
                 unmatched_path, ". Hand-extend ",
                 "data-raw/derived_data/jmp_wash_variables_complete.csv and ",
                 "re-run.", call. = FALSE)
        }

        warning(nrow(unmatched), " var_short value(s) not in the variable ",
                "lookup were dropped; written to ", unmatched_path,
                ". Extend data-raw/derived_data/jmp_wash_variables_complete.csv ",
                "and re-run.", call. = FALSE)
    }

    joined |>
        filter(!is.na(var_long))
}

# snapshot manifest --------------------------------------------------------

## Record a snapshot in the registry that 06_diff_report.R consumes.
## Schema per issue #1: release_id, snapshot_date, pipeline, file, source
## (live | wayback | git-history | jmpwashdata), notes. One row per file;
## re-registering a file replaces its row, so seeding and re-tidying are
## idempotent. Rows whose notes start with "duplicate", "alias",
## "superseded" or "input" are listed in the inventory but excluded from
## diff chains ("input" registers downloaded raw xlsx, which is tidied by
## 04/05 before it can be diffed).

append_manifest_row <- function(manifest_path, release_id, pipeline,
                                snapshot_date, file, source = "live",
                                notes = NA_character_) {

    new_row <- tibble(
        release_id = release_id,
        snapshot_date = as.character(snapshot_date),
        pipeline = pipeline,
        file = file,
        source = source,
        notes = notes
    )

    manifest <- if (file.exists(manifest_path)) {
        read_csv(manifest_path, show_col_types = FALSE,
                 col_types = "cccccc") |>
            filter(.data$file != .env$file) |>
            bind_rows(new_row)
    } else {
        new_row
    }

    manifest |>
        arrange(pipeline, release_id, snapshot_date, file) |>
        write_csv(manifest_path, na = "")

    invisible(manifest)
}

# downloads ----------------------------------------------------------------

## Download one washdata.org country file (or the world file with
## iso3 = "WLD"). Wrapped in tryCatch so one failing country never aborts
## a ~230-file run; the caller collects failures into a log. Bad downloads
## (HTML error pages served instead of xlsx) are detected via the zip
## magic bytes and removed. Returns "ok" or a short failure reason.

download_jmp_country <- function(iso3, dest,
                                 base_url = "https://washdata.org/data/country") {

    url <- paste0(base_url, "/", iso3, "/download")

    status <- tryCatch(
        suppressWarnings(download.file(url, destfile = dest, mode = "wb",
                                       quiet = TRUE)),
        error = \(e) -1L
    )

    if (!identical(status, 0L)) {
        if (file.exists(dest)) unlink(dest)
        return("download failed")
    }

    if (!is_xlsx(dest)) {
        unlink(dest)
        return("not an xlsx file (server returned an error page)")
    }

    "ok"
}

## An xlsx file is a zip archive; checking the magic bytes catches HTML
## error pages saved under an .xlsx name.

is_xlsx <- function(path) {
    file.exists(path) &&
        file.size(path) > 4 &&
        identical(readBin(path, "raw", 4),
                  as.raw(c(0x50, 0x4b, 0x03, 0x04)))
}

# snapshot readers --------------------------------------------------------

## Transparent reader for tidy snapshot files: the 2020 baseline exists
## only as .rds, later snapshots are .csv, downloads from #2/#4 may arrive
## compressed as .csv.gz (read_csv decompresses .gz transparently).

read_snapshot <- function(path) {

    ext <- tolower(tools::file_ext(sub("\\.gz$", "", path)))

    if (tolower(tools::file_ext(path)) == "rds") {
        as_tibble(readRDS(path))
    } else if (ext == "csv") {
        read_csv(path, show_col_types = FALSE)
    } else {
        stop("Unsupported snapshot format: ", basename(path),
             " (expected .rds, .csv or .csv.gz)", call. = FALSE)
    }
}

## Raw survey data (gather_raw_data.R lineage). Countries without any data
## are stored as all-NA placeholder rows; those are not data points and are
## dropped before diffing. residence, san_service_chain and var_long are
## functions of var_short and excluded from the identity key.
##
## The identity key is not stable across releases without normalization:
## the 2020-09-30 pull suffixes sources with a two-digit publication year
## ("CEN00") which the 2022-10-19 pull drops ("CEN"), the old "Survey"
## type was split into "Survey" and "Survey with microdata", the 2025
## release localizes type labels into the country language ("Encuesta con
## microdatos", "Перепись населения"), renames the national suffix _n to
## _t (total) and renames open defecation s_od_* to s_ns_* ("no service";
## verified value-identical on matched keys). Without normalization not a
## single key matches across releases. normalize = TRUE maps everything
## onto the legacy canonical vocabulary (English types, _n suffix, s_od).
## Where two source editions collapse onto the same key with conflicting
## values (Poland "ES12"/"ES13"), the newest edition is kept and a
## message reports how many rows were dropped.

jmp_type_map <- c(
    "Survey with microdata" = "Survey",
    "Encuesta" = "Survey",
    "Encuesta con microdatos" = "Survey",
    "Enquête" = "Survey",
    "Enquête avec microdonnées" = "Survey",
    "Обследование" = "Survey",
    "Обследование с микроданными" = "Survey",
    "الدراسة الاستقصائية" = "Survey",
    "المسح باستخدام البيانات الجزئية" = "Survey",
    "Censo" = "Census",
    "Recensement" = "Census",
    "Перепись населения" = "Census",
    "التعداد" = "Census",
    "Autre" = "Other",
    "Otro" = "Other",
    "آخر" = "Other",
    "Административная отчётность" = "Admin",
    "مصدر إداري" = "Admin"
)

read_raw_snapshot <- function(path, normalize = TRUE) {

    data <- read_snapshot(path) |>
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
            type = coalesce(unname(jmp_type_map[type]), type),
            var_short = str_replace(var_short, "_t$", "_n"),
            var_short = str_replace(var_short, "^s_ns_", "s_od_")
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
