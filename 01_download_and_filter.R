# ==============================================================================
# Title:        Download and Filter Bills
# Description:  Downloads the combined bill dataset from Google Drive (maintained
#               weekly by Biko via LegiScan API) and filters to target states
#               and education/finance keywords.
# Output:       filtered_bills.csv
# ==============================================================================

source("config/pkg_dependencies.R")
source("config/filter_settings.R")

# Main -------------------------------------------------------------------------

# 1. Download latest bill data from GDrive
cat("\n\U0001f535 Downloading bill data from Google Drive...\n")
drive_download(as_id(GDRIVE_FILE_ID), path = "gdrive_all_states_combined.csv", overwrite = TRUE)

bills_all <- read_csv("gdrive_all_states_combined.csv", show_col_types = FALSE)
cat("\U0001f535 Loaded", nrow(bills_all), "bills from all states\n")

# 2. Filter bill data using settings
bills_filtered <- bills_all |>
  filter(
    map_lgl(title, ~ any(str_detect(tolower(.x), KEYWORDS))) |
      map_lgl(description, ~ any(str_detect(tolower(.x), KEYWORDS))) |
      map_lgl(committee, ~ any(str_detect(tolower(.x), KEYWORDS)))
  ) |>
  filter(state %in% TARGET_STATES)

write_csv(bills_filtered, "filtered_bills.csv")

cat("\n\U0001f7e2 Wrote", nrow(bills_filtered), "filtered bills to filtered_bills.csv\n")
cat("  States:", length(unique(bills_filtered$state)),
    "of", length(TARGET_STATES), "target states represented\n\n")
