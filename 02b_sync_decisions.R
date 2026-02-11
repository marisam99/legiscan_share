# ==============================================================================
# Title:        Sync Decisions from Excel
# Description:  Reads Track decisions (TRUE/FALSE) from Master_Pull_List.xlsx
#               and saves them to tracking_decisions.csv. Run this after
#               reviewing and updating Track values in the Excel workbook.
#               Includes a migration mode for importing from old Excel structures.
# Output:       tracking_decisions.csv
# ==============================================================================

source("config/pkg_dependencies.R")
source("config/filter_settings.R")

# Load Tracking Data -----------------------------------------------------------

if (!file.exists("Master_Pull_List.xlsx")) {
  stop("\U0001f534 Excel file not found: ", "Master_Pull_List.xlsx")
}

if (!file.exists("tracking_decisions.csv")) {
  cat("\U0001f7e1 No tracking file found. Will create new one.\n")
  tracking_data <- tibble(
    bill_id = integer(),
    Track = logical(),
    decision_date = as.Date(character()),
    previous_status_date = character(),
    previous_action = character(),
    notes = character()
  )
} else {
  tracking_data <- read_csv("tracking_decisions.csv", show_col_types = FALSE)
  cat("\U0001f535 Loaded", nrow(tracking_data), "existing records from", "tracking_decisions.csv", "\n")
}

# Migration Mode ---------------------------------------------------------------

if (MIGRATION_MODE) {
  cat("\n\U0001f7e1 === MIGRATION MODE ===\n")
  cat("\U0001f535 Importing decisions from old Excel structure...\n")

  wb <- wb_load("Master_Pull_List.xlsx")
  sheets <- wb_get_sheet_names(wb)
  cat("  Available sheets:", paste(sheets, collapse = ", "), "\n")

  decisions_to_import <- tibble()

  if ("Tracked_Bills" %in% sheets) {
    tracked <- wb_read(wb, sheet = "Tracked_Bills") |>
      filter(!is.na(bill_id)) |>
      mutate(Track = TRUE) |>
      select(bill_id, Track)
    cat("  Found", nrow(tracked), "bills in Tracked_Bills\n")
    decisions_to_import <- bind_rows(decisions_to_import, tracked)
  }

  if ("Do_Not_Track" %in% sheets) {
    do_not_track <- wb_read(wb, sheet = "Do_Not_Track") |>
      filter(!is.na(bill_id)) |>
      mutate(Track = FALSE) |>
      select(bill_id, Track)
    cat("  Found", nrow(do_not_track), "bills in Do_Not_Track\n")
    decisions_to_import <- bind_rows(decisions_to_import, do_not_track)
  }

  if ("Filtered_Bills" %in% sheets) {
    filtered <- wb_read(wb, sheet = "Filtered_Bills") |>
      filter(!is.na(bill_id), !is.na(Track)) |>
      select(bill_id, Track)
    cat("  Found", nrow(filtered), "bills with Track set in Filtered_Bills\n")
    decisions_to_import <- bind_rows(decisions_to_import, filtered)
  }

  decisions_to_import <- decisions_to_import |>
    distinct(bill_id, .keep_all = TRUE) |>
    mutate(
      decision_date = Sys.Date(),
      previous_status_date = NA_character_,
      previous_action = NA_character_,
      notes = NA_character_
    )

  if (nrow(tracking_data) > 0) {
    tracking_data <- tracking_data |>
      rows_update(decisions_to_import, by = "bill_id", unmatched = "ignore")

    new_records <- decisions_to_import |>
      filter(!bill_id %in% tracking_data$bill_id)
    tracking_data <- bind_rows(tracking_data, new_records)
  } else {
    tracking_data <- decisions_to_import
  }

  write_csv(tracking_data, "tracking_decisions.csv")

  cat("\n\U0001f7e2 Migration complete!\n")
  cat("  Imported", nrow(decisions_to_import), "decisions to", "tracking_decisions.csv", "\n")
  cat("\n\U0001f535 Now set MIGRATION_MODE <- FALSE in config/filter_settings.R and run 02a_create_tracked_workbook.R\n\n")

# Sync Mode --------------------------------------------------------------------

} else {
  cat("\n\U0001f535 === SYNC MODE ===\n")
  cat("\U0001f535 Reading decisions from", "Master_Pull_List.xlsx", "...\n")

  wb <- wb_load("Master_Pull_List.xlsx")
  sheets <- wb_get_sheet_names(wb)
  decisions_updated <- 0

  # Process Needs_Review sheet
  if ("Needs_Review" %in% sheets) {
    needs_review <- wb_read(wb, sheet = "Needs_Review")

    if (!"bill_id" %in% names(needs_review)) {
      cat("  Needs_Review sheet has no bills to process\n")
    } else {
      new_decisions <- needs_review |>
        filter(!is.na(bill_id)) |>
        mutate(
          bill_id = as.numeric(bill_id),
          Track = ifelse(is.na(Track) | Track == FALSE | Track == "FALSE", FALSE, TRUE)
        ) |>
        select(bill_id, Track)

      n_tracked <- sum(new_decisions$Track == TRUE)
      n_not_tracked <- sum(new_decisions$Track == FALSE)
      cat("  Found", nrow(new_decisions), "bills in Needs_Review\n")
      cat("    Marked to track:", n_tracked, "\n")
      cat("    Not tracked:", n_not_tracked, "\n")

      if (nrow(new_decisions) > 0) {
        for (i in 1:nrow(new_decisions)) {
          bid <- new_decisions$bill_id[i]
          track_val <- new_decisions$Track[i]

          if (bid %in% tracking_data$bill_id) {
            tracking_data$Track[tracking_data$bill_id == bid] <- track_val
            tracking_data$decision_date[tracking_data$bill_id == bid] <- as.character(Sys.Date())
          } else {
            new_row <- tibble(
              bill_id = bid,
              Track = track_val,
              decision_date = as.character(Sys.Date()),
              previous_status_date = NA_character_,
              previous_action = NA_character_,
              notes = NA_character_
            )
            tracking_data <- bind_rows(tracking_data, new_row)
          }
          decisions_updated <- decisions_updated + 1
        }
      }
    }
  }

  # Process Tracked and Not_Tracked sheets for any changes
  for (sheet_name in c("Tracked", "Not_Tracked")) {
    if (sheet_name %in% sheets) {
      sheet_data <- wb_read(wb, sheet = sheet_name)

      if (!"bill_id" %in% names(sheet_data) || !"Track" %in% names(sheet_data)) {
        cat("  ", sheet_name, "sheet has no editable bills\n")
        next
      }

      sheet_decisions <- sheet_data |>
        filter(!is.na(bill_id)) |>
        mutate(
          bill_id = as.numeric(bill_id),
          Track = ifelse(is.na(Track) | Track == FALSE | Track == "FALSE", FALSE, TRUE)
        ) |>
        select(bill_id, Track)

      cat("  Found", nrow(sheet_decisions), "bills in", sheet_name, "\n")

      if (nrow(sheet_decisions) > 0) {
        for (i in 1:nrow(sheet_decisions)) {
          bid <- sheet_decisions$bill_id[i]
          track_val <- sheet_decisions$Track[i]

          if (bid %in% tracking_data$bill_id) {
            old_val <- tracking_data$Track[tracking_data$bill_id == bid]
            if (is.na(old_val) || old_val != track_val) {
              tracking_data$Track[tracking_data$bill_id == bid] <- track_val
              tracking_data$decision_date[tracking_data$bill_id == bid] <- as.character(Sys.Date())
              decisions_updated <- decisions_updated + 1
            }
          }
        }
      }
    }
  }

  write_csv(tracking_data, "tracking_decisions.csv")

  cat("\n\U0001f4ca Summary:\n")
  cat("  Decisions updated:", decisions_updated, "\n")
  cat("  Total tracked:", sum(tracking_data$Track == TRUE, na.rm = TRUE), "\n")
  cat("  Total not tracked:", sum(tracking_data$Track == FALSE, na.rm = TRUE), "\n")
  cat("  Pending decision:", sum(is.na(tracking_data$Track)), "\n")
  cat("\n\U0001f7e2 Saved to:", "tracking_decisions.csv", "\n")
  cat("\n\U0001f535 Run 02a_create_tracked_workbook.R to regenerate the Excel workbook.\n\n")
}
