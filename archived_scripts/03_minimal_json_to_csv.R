##############################################
#  R SCRIPT: Targeted JSON-to-CSV
#  Only the following columns:
#    bill_id, bill_number, title, description,
#    status, status_date, url,
#    action, importance, committee
##############################################

library(tidyverse)
library(jsonlite)

# 1) Define directories
bill_main_dir  <- "bill_folder"  # Where state folders (e.g., AL, CA, etc.) live
csv_output_dir <- "csv_bills"    # Folder to store the resulting CSVs

# Create output directory if it doesn't exist
if (!dir.exists(csv_output_dir)) {
  dir.create(csv_output_dir)
}

##############################################
# 2) Helper Functions
##############################################

# Because we only need `action` and `importance` from the `history` array,
# we can create a specialized function that extracts just those columns.
collapse_history_action <- function(history_data) {
  # If `history` is NULL or empty, return a single-row data frame
  # with `action` and `importance` as NA
  if (is.null(history_data) || length(history_data) == 0) {
    return(data.frame(action = NA, importance = NA, 
                      stringsAsFactors = FALSE))
  }
  
  # Convert history to a data frame
  hist_df <- as.data.frame(history_data, stringsAsFactors = FALSE)
  
  # Subset only `action` and `importance`, if they exist
  needed_cols <- intersect(c("action", "importance"), colnames(hist_df))
  
  # If one or both are missing, fill them with NA
  missing_cols <- setdiff(c("action", "importance"), needed_cols)
  for (mc in missing_cols) {
    hist_df[[mc]] <- NA
  }
  
  # Now hist_df has at least these columns: `action`, `importance`
  # Reorder for consistency
  hist_df <- hist_df[, c("action", "importance")]
  
  # Collapse multiple rows into semicolon-delimited strings
  collapsed <- apply(hist_df, 2, function(col) paste(col, collapse = "; "))
  
  # Return as a single-row data frame
  return(as.data.frame(t(collapsed), stringsAsFactors = FALSE))
}

# Helper to collapse committee info into a single "committee" column
collapse_committee <- function(committee_data) {
  # If `committee` is NULL or empty, return a single-row data frame
  # with committee as NA
  if (is.null(committee_data) || length(committee_data) == 0) {
    return(data.frame(committee = NA, stringsAsFactors = FALSE))
  }
  
  # Convert committee to a data frame
  # Some states might have multiple committees in an array
  committee_df <- as.data.frame(committee_data, stringsAsFactors = FALSE)
  
  # If there's no obvious name column, you can pick relevant fields
  # or just collapse the entire data frame. For now, we collapse all:
  collapsed <- apply(committee_df, 1, function(row) paste(row, collapse = ", "))
  
  # Combine multiple committees (rows) with semicolons
  collapsed_str <- paste(collapsed, collapse = "; ")
  
  # Return as a single row with one column named "committee"
  return(data.frame(committee = collapsed_str, stringsAsFactors = FALSE))
}

##############################################
# 3) Flatten Function for the 11 Target Columns
##############################################
# Now includes "committee" in final output.

flatten_bill_targeted <- function(bill) {
  # Helper for defaulting NULL -> NA
  `%||%` <- function(x, y) if (is.null(x)) y else x
  
  # --- (1) Top-level fields we want ---
  bill_core <- tibble(
    bill_id      = bill$bill_id      %||% NA,
    bill_number  = bill$bill_number  %||% NA,
    title        = bill$title        %||% NA,
    description  = bill$description  %||% NA,
    status       = bill$status       %||% NA,
    status_date  = bill$status_date  %||% NA,
    url          = bill$url          %||% NA
  )
  
  # --- (2) From `history`, we only want `action` and `importance` ---
  history_cols <- collapse_history_action(bill$history)
  
  # --- (3) From `committee`, we reintroduce a single column "committee" ---
  committee_col <- collapse_committee(bill$committee)
  
  # Combine them
  out_df <- cbind(bill_core, history_cols, committee_col)
  
  # Select only the columns we want in final output
  out_df <- out_df %>%
    select(
      bill_id, bill_number, title, description,
      status, status_date, url,
      action, importance, committee
    )
  
  return(out_df)
}

##############################################
# 4) Identify States & Process Each
##############################################

# We assume each state folder is directly under 'bill_folder'
# with a subdir named 'bill' containing the JSON files.
state_dirs <- list.dirs(bill_main_dir, recursive = FALSE)

for (state_dir in state_dirs) {
  state_abbrev <- basename(state_dir)  # e.g. "AL"
  
  # Bill folder path: "bill_folder/AL/bill"
  bill_dir <- file.path(state_dir, "bill")
  if (!dir.exists(bill_dir)) {
    message("No 'bill' subfolder for state: ", state_abbrev, " - skipping.")
    next
  }
  
  # Get all JSON files in that state's bill folder
  json_files <- list.files(bill_dir, pattern = "*.json", full.names = TRUE)
  if (length(json_files) == 0) {
    message("No JSON files in ", bill_dir, " - skipping.")
    next
  }
  
  # We'll accumulate rows for all bills in one data frame
  all_bills <- data.frame()
  
  for (file in json_files) {
    tryCatch({
      # Parse JSON
      bill_data <- fromJSON(file)
      
      # If there's a `bill` field, flatten it
      if (!is.null(bill_data$bill)) {
        flattened <- flatten_bill_targeted(bill_data$bill)
        all_bills <- bind_rows(all_bills, flattened)
      } else {
        warning("No 'bill' field in file: ", file)
      }
    }, error = function(e) {
      warning("Error processing file: ", file, " : ", e$message)
    })
  }
  
  # 5) Write CSV for this state
  csv_path <- file.path(csv_output_dir, paste0(state_abbrev, "_bills.csv"))
  write_csv(all_bills, csv_path)
  
  cat("\nCreated CSV for", state_abbrev, ":", csv_path, "\n")
}

cat("\nAll done! Check the 'csv_bills' folder for your targeted CSV outputs.\n")
