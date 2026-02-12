# ==============================================================================
# Title:        Create Tracked Workbook with Change Detection
# Description:  Creates an Excel workbook (Master_Pull_List.xlsx) with 4 sheets
#               for reviewing and tracking legislative bills: Needs_Review (new
#               and changed bills), Tracked, Not_Tracked, and Archive (dead/stuck).
#               Detects changes since last run and highlights them.
# Output:       Master_Pull_List.xlsx, tracking_decisions.csv
# ==============================================================================

# CONFIGS & CONSTANTS ------------------------------------------------------------

source("config/pkg_dependencies.R")
source("config/filter_settings.R")

CURRENT_DATE <- Sys.Date()
INPUT_FILE <- "filtered_bills.csv"
TRACKING_FILE <- "tracking_decisions.csv"
OUTPUT_FILE <- "Master_Pull_List.xlsx"

# Track column: TRUE = track this bill, FALSE = do not track (default)
# Workflow:
#   1. Open Master_Pull_List.xlsx → set Track=TRUE/FALSE in Needs_Review
#   2. Save the file → run 02b_sync_decisions.R
#   3. Run this script again to refresh Tracked/Not_Tracked views

# 1. Load Current Bills Data ----------------------------------------------------

cat("\n\U0001f535 Loading current bills from", INPUT_FILE, "...\n")
current_bills <- read_csv(INPUT_FILE, show_col_types = FALSE)
cat("  Loaded", nrow(current_bills), "bills\n")

# 2. Load or Initialize Tracking Data --------------------------------------------
if (!file.exists(TRACKING_FILE)) {
  cat("\U0001f7e1 No tracking file found. Creating new", TRACKING_FILE, "...\n")
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
  tracking_data <- read_csv(TRACKING_FILE, show_col_types = FALSE)
  cat("  Loaded", nrow(tracking_data), "tracked decisions")
}

# 3. Merge and Detect Changes -----------------------------------------------------

cat("\n\U0001f535 Detecting changes...\n")

merged_bills <- current_bills |>
  left_join(
    tracking_data |> select(bill_id, Track, decision_date,
                            previous_status_date, previous_action, notes),
    by = "bill_id"
  ) |>
  mutate(
    # Convert status_date to char. for comparison (handles numeric Excel dates)
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
    # Try to parse status_date - handle both date and numeric formats from Excel
    status_date_parsed = case_when(
      is.numeric(status_date) ~ as.Date(status_date, origin = "1899-12-30"),
      TRUE ~ as.Date(status_date)
    ),
    days_since_action = as.numeric(difftime(CURRENT_DATE, status_date_parsed, units = "days")),

    is_dead = grepl(DEAD_KEYWORDS, action, ignore.case = TRUE),
    is_stuck = !is_dead & !is.na(days_since_action) & days_since_action > STUCK_THRESHOLD_DAYS,
    archive_reason = case_when(
      is_dead ~ "Dead",
      is_stuck ~ "Stuck",
      TRUE ~ NA_character_
    )
  )
# Summary Stats
n_new <- sum(merged_bills$is_new, na.rm = TRUE)
n_status_changed <- sum(merged_bills$status_changed, na.rm = TRUE)
n_action_changed <- sum(merged_bills$action_changed, na.rm = TRUE)
n_needs_review <- sum(merged_bills$needs_review, na.rm = TRUE)

cat("  New bills:", n_new, "\n")
cat("  Status changed:", n_status_changed, "\n")
cat("  Action changed:", n_action_changed, "\n")
cat("  Total needs review:", n_needs_review, "\n")

# 4. Categorize Into Sheets -------------------------------------------------------

# Sheet 1: Needs_Review - new and changed bills
needs_review_df <- merged_bills |>
  filter(needs_review) |>
  mutate(
    bill_id = as.character(bill_id), # prevent scientific notation in Excel
    Track = ifelse(is.na(Track), FALSE, Track)
  ) |>
  select(state, bill_id, bill_number, title, Track,
         is_new, status_changed, action_changed,
         status_date, previous_status_date,
         action, previous_action,
         url, committee, description) |>
  arrange(desc(is_new), state, bill_number)

# Sheets 2 & 3: Tracked and Not_Tracked show ALL bills with those Track values
n_currently_tracked <- sum(merged_bills$Track == TRUE, na.rm = TRUE)
n_currently_not_tracked <- sum(merged_bills$Track == FALSE, na.rm = TRUE)

# Sheet 4: Archive - Dead or stuck bills
archive_df <- merged_bills |>
  filter(!is.na(archive_reason)) |>
  mutate(bill_id = as.character(bill_id)) |>
  select(state, bill_id, bill_number, title, Track, status_date,
         days_since_action, action, archive_reason, url) |>
  arrange(archive_reason, state, bill_number)

# Summary Stats
cat("\n\U0001f4ca Sheet counts:\n")
cat("  Needs_Review:", nrow(needs_review_df), "\n")
cat("  Tracked:", n_currently_tracked, "\n")
cat("  Not_Tracked:", n_currently_not_tracked, "\n")
cat("  Archive:", nrow(archive_df), "\n")

# 5. Create Workbook --------------------------------------------------------------

cat("\n\U0001f535 Creating Excel workbook...\n")

wb <- wb_workbook()

# --- Sheet 1: Needs_Review ---
wb <- wb_add_worksheet(wb, "Needs_Review")

if (nrow(needs_review_df) > 0) {
  wb <- wb_add_data(wb, "Needs_Review", needs_review_df)

  # Header style
  wb <- wb_add_font(wb, "Needs_Review", dims = wb_dims(rows = 1, cols = 1:ncol(needs_review_df)),
                    bold = TRUE, color = wb_color(hex = "FFFFFF"))
  wb <- wb_add_fill(wb, "Needs_Review", dims = wb_dims(rows = 1, cols = 1:ncol(needs_review_df)),
                    color = wb_color(hex = "4472C4"))
  wb <- wb_add_cell_style(wb, "Needs_Review", dims = wb_dims(rows = 1, cols = 1:ncol(needs_review_df)),
                          horizontal = "center")

  # Highlight new bills (light blue rows)
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

  # Track column dropdown
  track_col <- which(names(needs_review_df) == "Track")
  track_col_letter <- int2col(track_col)
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

# --- Sheet 2: Tracked (ALL bills with Track=TRUE, editable) ---
wb <- wb_add_worksheet(wb, "Tracked")

tracked_bills <- merged_bills |>
  filter(Track == TRUE) |>
  mutate(bill_id = as.character(bill_id)) |>
  select(state, bill_id, bill_number, title, Track, status_date,
         action, url, committee, description)

if (nrow(tracked_bills) > 0) {
  wb <- wb_add_data(wb, "Tracked", tracked_bills)
  wb <- wb_add_font(wb, "Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(tracked_bills)),
                    bold = TRUE, color = wb_color(hex = "FFFFFF"))
  wb <- wb_add_fill(wb, "Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(tracked_bills)),
                    color = wb_color(hex = "4472C4"))
  wb <- wb_add_cell_style(wb, "Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(tracked_bills)),
                          horizontal = "center")

  track_col_t <- which(names(tracked_bills) == "Track")
  track_col_letter_t <- int2col(track_col_t)
  wb <- wb_add_data_validation(wb, "Tracked",
                                dims = paste0(track_col_letter_t, "2:", track_col_letter_t, nrow(tracked_bills) + 1),
                                type = "list",
                                value = '"TRUE,FALSE"',
                                showInputMsg = TRUE,
                                promptTitle = "Track this bill?",
                                prompt = "Change to FALSE to stop tracking")

  wb <- wb_set_col_widths(wb, "Tracked", cols = 1:ncol(tracked_bills), widths = "auto")
} else {
  wb <- wb_add_data(wb, "Tracked", data.frame(Message = "No tracked bills yet - mark Track=TRUE in Needs_Review"))
}
wb <- wb_freeze_pane(wb, "Tracked", first_row = TRUE)

# --- Sheet 3: Not_Tracked (ALL bills with Track=FALSE, editable) ---
wb <- wb_add_worksheet(wb, "Not_Tracked")

not_tracked_bills <- merged_bills |>
  filter(Track == FALSE) |>
  mutate(bill_id = as.character(bill_id)) |>
  select(state, bill_id, bill_number, title, Track, status_date,
         action, url, committee, description)

if (nrow(not_tracked_bills) > 0) {
  wb <- wb_add_data(wb, "Not_Tracked", not_tracked_bills)
  wb <- wb_add_font(wb, "Not_Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(not_tracked_bills)),
                    bold = TRUE, color = wb_color(hex = "FFFFFF"))
  wb <- wb_add_fill(wb, "Not_Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(not_tracked_bills)),
                    color = wb_color(hex = "4472C4"))
  wb <- wb_add_cell_style(wb, "Not_Tracked", dims = wb_dims(rows = 1, cols = 1:ncol(not_tracked_bills)),
                          horizontal = "center")

  track_col_nt <- which(names(not_tracked_bills) == "Track")
  track_col_letter_nt <- int2col(track_col_nt)
  wb <- wb_add_data_validation(wb, "Not_Tracked",
                                dims = paste0(track_col_letter_nt, "2:", track_col_letter_nt, nrow(not_tracked_bills) + 1),
                                type = "list",
                                value = '"TRUE,FALSE"',
                                showInputMsg = TRUE,
                                promptTitle = "Track this bill?",
                                prompt = "Change to TRUE to start tracking")

  wb <- wb_set_col_widths(wb, "Not_Tracked", cols = 1:ncol(not_tracked_bills), widths = "auto")
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

  # Gray for dead bills
  dead_rows <- which(archive_df$archive_reason == "Dead") + 1
  if (length(dead_rows) > 0) {
    for (row in dead_rows) {
      wb <- wb_add_fill(wb, "Archive", dims = wb_dims(rows = row, cols = 1:ncol(archive_df)),
                        color = wb_color(hex = "E0E0E0"))
      wb <- wb_add_font(wb, "Archive", dims = wb_dims(rows = row, cols = 1:ncol(archive_df)),
                        color = wb_color(hex = "666666"))
    }
  }

  # Orange for stuck bills
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

# 6. Save Workbook --------------------------------------------------------------

wb_save(wb, OUTPUT_FILE, overwrite = TRUE)
cat("\n\U0001f7e2 Created workbook:", OUTPUT_FILE, "\n")

# 7. Update Tracking File -------------------------------------------------------

cat("\U0001f535 Updating tracking file with current bill states...\n")

# For existing tracked bills, update the previous values
# For new bills, add them with Track=NA (to be decided)
updated_tracking <- merged_bills |>
  select(bill_id) |>
  left_join(tracking_data |> select(bill_id, Track, decision_date, notes), by = "bill_id") |>
  mutate(
    previous_status_date = current_bills$status_date[match(bill_id, current_bills$bill_id)],
    previous_action = current_bills$action[match(bill_id, current_bills$bill_id)]
  ) |>
  select(bill_id, Track, decision_date, previous_status_date, previous_action, notes)

write_csv(updated_tracking, TRACKING_FILE)
cat("Updated tracking file:", TRACKING_FILE, "\n")

# 8. Summary ----------------------------------------------------------------------

cat("\n\U0001f4ca Summary:\n")
cat("  Total bills processed:", nrow(current_bills), "\n")
cat("  New bills (needs Track decision):", n_new, "\n")
cat("  Changed bills:", n_status_changed + n_action_changed, "\n")
cat("  Bills in Needs_Review:", nrow(needs_review_df), "\n")
cat("  Tracked (Track=TRUE):", n_currently_tracked, "\n")
cat("  Not tracked (Track=FALSE):", n_currently_not_tracked, "\n")
cat("  Archived:", nrow(archive_df), "\n")

cat("\n\U0001f535 Next steps:\n")
cat("  1. Open", OUTPUT_FILE, "and review the Needs_Review sheet\n")
cat("  2. Set Track=TRUE for bills to track (FALSE is default)\n")
cat("  3. Save the Excel file\n")
cat("  4. Run 02b_sync_decisions.R to save your decisions\n")
cat("  5. Run this script again to refresh Tracked/Not_Tracked views\n\n")
