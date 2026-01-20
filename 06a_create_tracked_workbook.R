# R SCRIPT: Create Tracked Workbook with Change Detection
# Creates Excel workbook with 4 review-focused sheets:
#   - Needs_Review: New bills + bills with changes (main data entry sheet)
#   - Tracked: Bills where Track=TRUE (static snapshot, refreshes when script runs)
#   - Not_Tracked: Bills where Track=FALSE (static snapshot, refreshes when script runs)
#   - Archive: Dead or stuck bills
#
# Track column behavior:
#   - TRUE = Track this bill (select from dropdown)
#   - FALSE = Do not track (default - no action needed)
#
# Workflow:
#   1. Open Master_Pull_List.xlsx and set Track=TRUE/FALSE in Needs_Review
#   2. Save the file and run 06b_sync_decisions_from_excel.R
#   3. Run this script again to refresh the Tracked/Not_Tracked views
#
# Requires: openxlsx2, tidyverse
# Install openxlsx2 with: install.packages("openxlsx2")
library(tidyverse)
library(openxlsx2)

# ============================================
# CONFIGURATION
# ============================================
CURRENT_DATE <- Sys.Date()
STUCK_THRESHOLD_DAYS <- 45

INPUT_FILE <- "filtered_bills.csv"
TRACKING_FILE <- "tracking_decisions.csv"
OUTPUT_FILE <- "Master_Pull_List.xlsx"

# ============================================
# 1. LOAD CURRENT BILLS DATA
# ============================================
cat("Loading current bills from", INPUT_FILE, "...\n")
current_bills <- read_csv(INPUT_FILE, show_col_types = FALSE)
cat("  Loaded", nrow(current_bills), "bills\n")

# ============================================
# 2. LOAD OR INITIALIZE TRACKING DATA
# ============================================
if (!file.exists(TRACKING_FILE)) {
  cat("No tracking file found. Creating new", TRACKING_FILE, "...\n")
  tracking_data <- tibble(
    bill_id = integer(),
    Track = logical(),
    decision_date = as.Date(character()),
    previous_status_date = character(),
    previous_action = character(),
    notes = character()
  )
  write_csv(tracking_data, TRACKING_FILE)
} else {
  cat("Loading tracking decisions from", TRACKING_FILE, "...\n")
  tracking_data <- read_csv(TRACKING_FILE, show_col_types = FALSE)
  cat("  Loaded", nrow(tracking_data), "tracked decisions\n")
}

# ============================================
# 3. MERGE AND DETECT CHANGES
# ============================================
cat("Detecting changes...\n")

merged_bills <- current_bills %>%
  left_join(
    tracking_data %>% select(bill_id, Track, decision_date,
                             previous_status_date, previous_action, notes),
    by = "bill_id"
  ) %>%
  mutate(
    # Convert status_date to character for comparison (handles numeric Excel dates)
    status_date_str = as.character(status_date),
    prev_status_str = as.character(previous_status_date),

    # Change detection flags
    is_new = is.na(Track),
    status_changed = !is.na(previous_status_date) &
                     status_date_str != prev_status_str,
    action_changed = !is.na(previous_action) &
                     action != previous_action,
    needs_review = is_new | status_changed | action_changed,

    # Archive detection (Dead/Stuck bills)
    # Try to parse status_date - handle both date and numeric formats
    status_date_parsed = case_when(
      is.numeric(status_date) ~ as.Date(status_date, origin = "1899-12-30"),
      TRUE ~ as.Date(status_date)
    ),
    days_since_action = as.numeric(difftime(CURRENT_DATE, status_date_parsed, units = "days")),

    is_dead = grepl("died in committee|fail|postpone|postponed|inexpedient|killed|veto",
                    action, ignore.case = TRUE),
    is_stuck = !is_dead & !is.na(days_since_action) & days_since_action > STUCK_THRESHOLD_DAYS,
    archive_reason = case_when(
      is_dead ~ "Dead",
      is_stuck ~ "Stuck",
      TRUE ~ NA_character_
    )
  )

# Summary stats
n_new <- sum(merged_bills$is_new, na.rm = TRUE)
n_status_changed <- sum(merged_bills$status_changed, na.rm = TRUE)
n_action_changed <- sum(merged_bills$action_changed, na.rm = TRUE)
n_needs_review <- sum(merged_bills$needs_review, na.rm = TRUE)

cat("  New bills:", n_new, "\n")
cat("  Status changed:", n_status_changed, "\n")
cat("  Action changed:", n_action_changed, "\n")
cat("  Total needs review:", n_needs_review, "\n")

# ============================================
# 4. CATEGORIZE INTO SHEETS
# ============================================

# Sheet 1: Needs_Review - New bills + changed bills
needs_review_df <- merged_bills %>%
  filter(needs_review) %>%
  mutate(bill_id = as.character(bill_id)) %>%  # Prevent scientific notation in Excel
  select(state, bill_id, bill_number, title, Track,
         is_new, status_changed, action_changed,
         status_date, previous_status_date,
         action, previous_action,
         url, committee, description) %>%
  arrange(desc(is_new), state, bill_number)

# Sheet 2 & 3: Tracked and Not_Tracked sheets will use dynamic FILTER formulas
# These pull from Needs_Review in real-time, so no static dataframes needed
# The formulas will automatically show bills based on the Track column value
n_currently_tracked <- sum(needs_review_df$Track == TRUE, na.rm = TRUE)
n_currently_not_tracked <- sum(needs_review_df$Track == FALSE, na.rm = TRUE)

# Sheet 4: Archive - Dead or stuck bills
archive_df <- merged_bills %>%
  filter(!is.na(archive_reason)) %>%
  mutate(bill_id = as.character(bill_id)) %>%  # Prevent scientific notation in Excel
  select(state, bill_id, bill_number, title, Track, status_date,
         days_since_action, action, archive_reason, url) %>%
  arrange(archive_reason, state, bill_number)

cat("\nSheet counts:\n")
cat("  Needs_Review:", nrow(needs_review_df), "\n")
cat("  Tracked (dynamic):", n_currently_tracked, "bills with Track=TRUE\n")
cat("  Not_Tracked (dynamic):", n_currently_not_tracked, "bills with Track=FALSE\n")
cat("  Archive:", nrow(archive_df), "\n")

# ============================================
# 5. CREATE WORKBOOK WITH STYLES
# ============================================
cat("\nCreating Excel workbook...\n")

wb <- wb_workbook()

# --- Sheet 1: Needs_Review ---
wb <- wb_add_worksheet(wb, "Needs_Review")
if (nrow(needs_review_df) > 0) {
  # Prepare data: Convert Track to FALSE (unchecked) for new bills
  # This way, unchecked = not tracked (default), checked = track
  needs_review_df <- needs_review_df %>%
    mutate(Track = ifelse(is.na(Track), FALSE, Track))

  wb <- wb_add_data(wb, "Needs_Review", needs_review_df)

  # Header style (bold, blue background, white text)
  wb <- wb_add_font(wb, "Needs_Review", dims = wb_dims(rows = 1, cols = 1:ncol(needs_review_df)),
                    bold = TRUE, color = wb_color(hex = "FFFFFF"))
  wb <- wb_add_fill(wb, "Needs_Review", dims = wb_dims(rows = 1, cols = 1:ncol(needs_review_df)),
                    color = wb_color(hex = "4472C4"))
  wb <- wb_add_cell_style(wb, "Needs_Review", dims = wb_dims(rows = 1, cols = 1:ncol(needs_review_df)),
                          horizontal = "center")

  # Highlight entire row for new bills (light blue)
  if (any(needs_review_df$is_new, na.rm = TRUE)) {
    new_rows <- which(needs_review_df$is_new) + 1
    for (row in new_rows) {
      wb <- wb_add_fill(wb, "Needs_Review", dims = wb_dims(rows = row, cols = 1:ncol(needs_review_df)),
                        color = wb_color(hex = "CCE5FF"))
    }
  }

  # Highlight changed status_date cells (yellow)
  status_col <- which(names(needs_review_df) == "status_date")
  if (any(needs_review_df$status_changed, na.rm = TRUE)) {
    changed_rows <- which(needs_review_df$status_changed) + 1
    for (row in changed_rows) {
      wb <- wb_add_fill(wb, "Needs_Review", dims = wb_dims(rows = row, cols = status_col),
                        color = wb_color(hex = "FFFF99"))
    }
  }

  # Highlight changed action cells (yellow)
  action_col <- which(names(needs_review_df) == "action")
  if (any(needs_review_df$action_changed, na.rm = TRUE)) {
    changed_rows <- which(needs_review_df$action_changed) + 1
    for (row in changed_rows) {
      wb <- wb_add_fill(wb, "Needs_Review", dims = wb_dims(rows = row, cols = action_col),
                        color = wb_color(hex = "FFFF99"))
    }
  }

  # Add checkbox data validation for Track column
  # In Excel, checkboxes work with TRUE/FALSE values
  track_col <- which(names(needs_review_df) == "Track")
  track_col_letter <- int2col(track_col)

  # Add data validation to restrict to TRUE/FALSE (checkbox behavior)
  wb <- wb_add_data_validation(wb, "Needs_Review",
                                dims = paste0(track_col_letter, "2:", track_col_letter, nrow(needs_review_df) + 1),
                                type = "list",
                                value = '"TRUE,FALSE"',
                                showInputMsg = TRUE,
                                promptTitle = "Track this bill?",
                                prompt = "Check TRUE to track, leave FALSE to not track")

  wb <- wb_set_col_widths(wb, "Needs_Review", cols = 1:ncol(needs_review_df), widths = "auto")
  wb <- wb_freeze_pane(wb, "Needs_Review", first_row = TRUE)
} else {
  wb <- wb_add_data(wb, "Needs_Review", data.frame(Message = "No bills need review"))
}

# --- Sheet 2: Tracked (Static view of bills with Track=TRUE) ---
wb <- wb_add_worksheet(wb, "Tracked")

# Filter needs_review_df for bills marked TRUE
tracked_from_review <- needs_review_df %>%
  filter(Track == TRUE) %>%
  select(state, bill_id, bill_number, title, status_date,
         action, url, committee, description)

if (nrow(tracked_from_review) > 0) {
  wb <- wb_add_data(wb, "Tracked", tracked_from_review)
  wb <- wb_add_font(wb, "Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(tracked_from_review)),
                    bold = TRUE, color = wb_color(hex = "FFFFFF"))
  wb <- wb_add_fill(wb, "Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(tracked_from_review)),
                    color = wb_color(hex = "4472C4"))
  wb <- wb_add_cell_style(wb, "Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(tracked_from_review)),
                          horizontal = "center")
  wb <- wb_set_col_widths(wb, "Tracked", cols = 1:ncol(tracked_from_review), widths = "auto")
} else {
  wb <- wb_add_data(wb, "Tracked", data.frame(Message = "No tracked bills yet - mark Track=TRUE in Needs_Review"))
}
wb <- wb_freeze_pane(wb, "Tracked", first_row = TRUE)

# --- Sheet 3: Not_Tracked (Static view of bills with Track=FALSE) ---
wb <- wb_add_worksheet(wb, "Not_Tracked")

# Filter needs_review_df for bills marked FALSE
not_tracked_from_review <- needs_review_df %>%
  filter(Track == FALSE) %>%
  select(state, bill_id, bill_number, title, status_date,
         action, url, committee, description)

if (nrow(not_tracked_from_review) > 0) {
  wb <- wb_add_data(wb, "Not_Tracked", not_tracked_from_review)
  wb <- wb_add_font(wb, "Not_Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(not_tracked_from_review)),
                    bold = TRUE, color = wb_color(hex = "FFFFFF"))
  wb <- wb_add_fill(wb, "Not_Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(not_tracked_from_review)),
                    color = wb_color(hex = "4472C4"))
  wb <- wb_add_cell_style(wb, "Not_Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(not_tracked_from_review)),
                          horizontal = "center")
  wb <- wb_set_col_widths(wb, "Not_Tracked", cols = 1:ncol(not_tracked_from_review), widths = "auto")
} else {
  wb <- wb_add_data(wb, "Not_Tracked", data.frame(Message = "No untracked bills yet"))
}
wb <- wb_freeze_pane(wb, "Not_Tracked", first_row = TRUE)

# --- Sheet 4: Archive ---
wb <- wb_add_worksheet(wb, "Archive")
if (nrow(archive_df) > 0) {
  wb <- wb_add_data(wb, "Archive", archive_df)
  wb <- wb_add_font(wb, "Archive", dims = wb_dims(rows = 1, cols = 1:ncol(archive_df)),
                    bold = TRUE, color = wb_color(hex = "FFFFFF"))
  wb <- wb_add_fill(wb, "Archive", dims = wb_dims(rows = 1, cols = 1:ncol(archive_df)),
                    color = wb_color(hex = "4472C4"))
  wb <- wb_add_cell_style(wb, "Archive", dims = wb_dims(rows = 1, cols = 1:ncol(archive_df)),
                          horizontal = "center")

  # Style dead bills (gray)
  dead_rows <- which(archive_df$archive_reason == "Dead") + 1
  if (length(dead_rows) > 0) {
    for (row in dead_rows) {
      wb <- wb_add_fill(wb, "Archive", dims = wb_dims(rows = row, cols = 1:ncol(archive_df)),
                        color = wb_color(hex = "E0E0E0"))
      wb <- wb_add_font(wb, "Archive", dims = wb_dims(rows = row, cols = 1:ncol(archive_df)),
                        color = wb_color(hex = "666666"))
    }
  }

  # Style stuck bills (orange-ish)
  stuck_rows <- which(archive_df$archive_reason == "Stuck") + 1
  if (length(stuck_rows) > 0) {
    for (row in stuck_rows) {
      wb <- wb_add_fill(wb, "Archive", dims = wb_dims(rows = row, cols = 1:ncol(archive_df)),
                        color = wb_color(hex = "FFE4B5"))
      wb <- wb_add_font(wb, "Archive", dims = wb_dims(rows = row, cols = 1:ncol(archive_df)),
                        color = wb_color(hex = "8B4513"))
    }
  }

  wb <- wb_set_col_widths(wb, "Archive", cols = 1:ncol(archive_df), widths = "auto")
  wb <- wb_freeze_pane(wb, "Archive", first_row = TRUE)
} else {
  wb <- wb_add_data(wb, "Archive", data.frame(Message = "No archived bills"))
}

# ============================================
# 6. SAVE WORKBOOK
# ============================================
wb_save(wb, OUTPUT_FILE, overwrite = TRUE)
cat("\nCreated workbook:", OUTPUT_FILE, "\n")

# ============================================
# 7. UPDATE TRACKING FILE WITH CURRENT VALUES
# ============================================
cat("Updating tracking file with current bill states...\n")

# For existing tracked bills, update the previous values
# For new bills, add them with Track=NA (to be decided)
updated_tracking <- merged_bills %>%
  select(bill_id) %>%
  left_join(tracking_data %>% select(bill_id, Track, decision_date, notes), by = "bill_id") %>%
  mutate(
    # Store current values as "previous" for next comparison
    previous_status_date = current_bills$status_date[match(bill_id, current_bills$bill_id)],
    previous_action = current_bills$action[match(bill_id, current_bills$bill_id)]
  ) %>%
  select(bill_id, Track, decision_date, previous_status_date, previous_action, notes)

write_csv(updated_tracking, TRACKING_FILE)
cat("Updated tracking file:", TRACKING_FILE, "\n")

# ============================================
# 8. SUMMARY
# ============================================
cat("\n=== SUMMARY ===\n")
cat("Total bills processed:", nrow(current_bills), "\n")
cat("New bills (needs Track decision):", n_new, "\n")
cat("Changed bills:", n_status_changed + n_action_changed, "\n")
cat("Bills in Needs_Review sheet:", nrow(needs_review_df), "\n")
cat("Bills currently marked Track=TRUE:", n_currently_tracked, "\n")
cat("Bills currently marked Track=FALSE:", n_currently_not_tracked, "\n")
cat("Bills in Archive sheet:", nrow(archive_df), "\n")
cat("\nWorkflow next steps:\n")
cat("1. Open", OUTPUT_FILE, "and review the Needs_Review sheet\n")
cat("2. Set Track = TRUE for bills you want to track (FALSE is default = not tracked)\n")
cat("3. Save the Excel file\n")
cat("4. Run 06b_sync_decisions_from_excel.R to save your decisions\n")
cat("5. Run this script again to refresh the Tracked/Not_Tracked sheet views\n")
