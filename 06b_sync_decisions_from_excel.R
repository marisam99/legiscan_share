# R SCRIPT: Sync Decisions from Excel to Tracking File
# Reads user's Track decisions from the Excel workbook and saves to tracking_decisions.csv
#
# Run this AFTER you've reviewed and updated Track values in the Excel file.
#
# Track column logic:
#   - TRUE (checked) = Track this bill
#   - FALSE (unchecked) = Do not track this bill
#   - Bills with Track=FALSE are automatically classified as "not tracked"
#
# Also includes migration mode to import existing decisions from old Excel structure.
#
# Requires: openxlsx2, tidyverse
# Install openxlsx2 with: install.packages("openxlsx2")

library(tidyverse)
library(openxlsx2)

# ============================================
# CONFIGURATION
# ============================================
EXCEL_FILE <- "Master_Pull_List.xlsx"
TRACKING_FILE <- "tracking_decisions.csv"

# Set to TRUE to import from old Excel structure (Tracked_Bills / Do_Not_Track sheets)
# Set to FALSE for normal operation (sync from Needs_Review sheet)
MIGRATION_MODE <- FALSE

# ============================================
# CHECK FILES EXIST
# ============================================
if (!file.exists(EXCEL_FILE)) {
  stop("Excel file not found: ", EXCEL_FILE)
}

if (!file.exists(TRACKING_FILE)) {
  cat("Warning: Tracking file not found. Will create new one.\n")
  tracking_data <- tibble(
    bill_id = integer(),
    Track = logical(),
    decision_date = as.Date(character()),
    previous_status_date = character(),
    previous_action = character(),
    notes = character()
  )
} else {
  tracking_data <- read_csv(TRACKING_FILE, show_col_types = FALSE)
  cat("Loaded", nrow(tracking_data), "existing records from tracking file\n")
}

# ============================================
# MIGRATION MODE: Import from old Excel structure
# ============================================
if (MIGRATION_MODE) {
  cat("\n=== MIGRATION MODE ===\n")
  cat("Importing decisions from old Excel structure...\n")

  # Read the old sheets
  wb <- wb_load(EXCEL_FILE)
  sheets <- wb_get_sheet_names(wb)
  cat("Available sheets:", paste(sheets, collapse = ", "), "\n")

  decisions_to_import <- tibble()

  # Import Tracked_Bills sheet (Track = TRUE)
  if ("Tracked_Bills" %in% sheets) {
    tracked <- wb_read(wb, sheet = "Tracked_Bills")
    tracked <- tracked %>%
      filter(!is.na(bill_id)) %>%
      mutate(Track = TRUE) %>%
      select(bill_id, Track)
    cat("  Found", nrow(tracked), "bills in Tracked_Bills\n")
    decisions_to_import <- bind_rows(decisions_to_import, tracked)
  }

  # Import Do_Not_Track sheet (Track = FALSE)
  if ("Do_Not_Track" %in% sheets) {
    do_not_track <- wb_read(wb, sheet = "Do_Not_Track")
    do_not_track <- do_not_track %>%
      filter(!is.na(bill_id)) %>%
      mutate(Track = FALSE) %>%
      select(bill_id, Track)
    cat("  Found", nrow(do_not_track), "bills in Do_Not_Track\n")
    decisions_to_import <- bind_rows(decisions_to_import, do_not_track)
  }

  # Also check Filtered_Bills for any Track values
  if ("Filtered_Bills" %in% sheets) {
    filtered <- wb_read(wb, sheet = "Filtered_Bills")
    filtered <- filtered %>%
      filter(!is.na(bill_id), !is.na(Track)) %>%
      select(bill_id, Track)
    cat("  Found", nrow(filtered), "bills with Track set in Filtered_Bills\n")
    decisions_to_import <- bind_rows(decisions_to_import, filtered)
  }

  # Remove duplicates (keep first occurrence)
  decisions_to_import <- decisions_to_import %>%
    distinct(bill_id, .keep_all = TRUE) %>%
    mutate(
      decision_date = Sys.Date(),
      previous_status_date = NA_character_,
      previous_action = NA_character_,
      notes = NA_character_
    )

  # Merge with existing tracking data
  if (nrow(tracking_data) > 0) {
    # Update existing records with imported decisions
    tracking_data <- tracking_data %>%
      rows_update(decisions_to_import, by = "bill_id", unmatched = "ignore")

    # Add new records that weren't in tracking_data
    new_records <- decisions_to_import %>%
      filter(!bill_id %in% tracking_data$bill_id)
    tracking_data <- bind_rows(tracking_data, new_records)
  } else {
    tracking_data <- decisions_to_import
  }

  write_csv(tracking_data, TRACKING_FILE)
  cat("\nMigration complete!\n")
  cat("Imported", nrow(decisions_to_import), "decisions to", TRACKING_FILE, "\n")
  cat("\nNow set MIGRATION_MODE <- FALSE and run 06b_create_tracked_workbook.R\n")

} else {
  # ============================================
  # NORMAL MODE: Sync from new Excel structure
  # ============================================
  cat("\n=== SYNC MODE ===\n")
  cat("Reading decisions from", EXCEL_FILE, "...\n")

  wb <- wb_load(EXCEL_FILE)
  sheets <- wb_get_sheet_names(wb)
  decisions_updated <- 0

  # Read Needs_Review sheet for new decisions
  # NEW LOGIC: All bills in Needs_Review now have Track values
  #   - TRUE (checked) = Track this bill
  #   - FALSE (unchecked) = Do NOT track (this is the default)
  # So we process ALL bills, not just those with non-NA Track values
  if ("Needs_Review" %in% sheets) {
    needs_review <- wb_read(wb, sheet = "Needs_Review")

    # Check if this is a placeholder "no bills" message
    if (!"bill_id" %in% names(needs_review)) {
      cat("  Needs_Review sheet has no bills to process\n")
    } else {
      # Process all bills - FALSE means "not tracked" (user didn't check the box)
      new_decisions <- needs_review %>%
        filter(!is.na(bill_id)) %>%
        mutate(
          # Convert bill_id to numeric (in case it was read as character)
          bill_id = as.numeric(bill_id),
          # Treat NA or FALSE as "not tracked", only TRUE means "track"
          Track = ifelse(is.na(Track) | Track == FALSE | Track == "FALSE", FALSE, TRUE)
        ) %>%
        select(bill_id, Track)

      n_tracked <- sum(new_decisions$Track == TRUE)
      n_not_tracked <- sum(new_decisions$Track == FALSE)
      cat("  Found", nrow(new_decisions), "bills in Needs_Review\n")
      cat("    - Marked to track (checked):", n_tracked, "\n")
      cat("    - Not tracked (unchecked):", n_not_tracked, "\n")

      if (nrow(new_decisions) > 0) {
        # Update tracking data
        for (i in 1:nrow(new_decisions)) {
          bid <- new_decisions$bill_id[i]
          track_val <- new_decisions$Track[i]

          if (bid %in% tracking_data$bill_id) {
            # Update existing record
            tracking_data$Track[tracking_data$bill_id == bid] <- track_val
            tracking_data$decision_date[tracking_data$bill_id == bid] <- as.character(Sys.Date())
          } else {
            # Add new record
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

  # Also read from Tracked and Not_Tracked sheets for any changes
  for (sheet_name in c("Tracked", "Not_Tracked")) {
    if (sheet_name %in% sheets) {
      sheet_data <- wb_read(wb, sheet = sheet_name)

      # Check if this is a placeholder message
      if (!"bill_id" %in% names(sheet_data) || !"Track" %in% names(sheet_data)) {
        cat("  ", sheet_name, "sheet has no editable bills\n")
        next
      }

      sheet_decisions <- sheet_data %>%
        filter(!is.na(bill_id)) %>%
        mutate(
          bill_id = as.numeric(bill_id),
          Track = ifelse(is.na(Track) | Track == FALSE | Track == "FALSE", FALSE, TRUE)
        ) %>%
        select(bill_id, Track)

      cat("  Found", nrow(sheet_decisions), "bills in", sheet_name, "\n")

      if (nrow(sheet_decisions) > 0) {
        for (i in 1:nrow(sheet_decisions)) {
          bid <- sheet_decisions$bill_id[i]
          track_val <- sheet_decisions$Track[i]

          if (bid %in% tracking_data$bill_id) {
            # Only update if value changed
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

  # Save updated tracking data
  write_csv(tracking_data, TRACKING_FILE)

  cat("\n=== SUMMARY ===\n")
  cat("Decisions updated:", decisions_updated, "\n")
  cat("Total tracked bills:", sum(tracking_data$Track == TRUE, na.rm = TRUE), "\n")
  cat("Total not-tracked bills:", sum(tracking_data$Track == FALSE, na.rm = TRUE), "\n")
  cat("Bills pending decision:", sum(is.na(tracking_data$Track)), "\n")
  cat("\nSaved to:", TRACKING_FILE, "\n")
  cat("\nRun 06a_create_tracked_workbook.R to regenerate the Excel workbook.\n")
}
