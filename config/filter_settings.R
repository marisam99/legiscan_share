# ==============================================================================
# Title:        Project Settings
# Description:  Centralized configuration for the legislative bill tracking
#               pipeline. Edit these values to customize filtering and
#               analysis thresholds.
# Output:       Constants loaded into the R session
# ==============================================================================

# Data Source ------------------------------------------------------------------

GDRIVE_FILE_ID <- "1K1MJ7uB5aXvZLYcq4N8VwjSOFMDkisvd"

# Filtering --------------------------------------------------------------------

TARGET_STATES <- c("CA", "NY", "TX")  # Replace with your target states
KEYWORDS <- c("keyword1", "keyword2")  # Replace with your search terms

# Analysis Thresholds ----------------------------------------------------------

STUCK_THRESHOLD_DAYS <- 45
DEAD_KEYWORDS <- "died in committee|fail|postpone|postponed|inexpedient|killed|veto"

# Sync Settings ----------------------------------------------------------------

# Set TRUE to import from old Excel structure (Tracked_Bills / Do_Not_Track)
MIGRATION_MODE <- FALSE

# Project Overrides ------------------------------------------------------------
# To customize settings for a specific project, create config/project_settings.R
# and override any variables above. See README for details.

project_settings <- file.path("config", "project_settings.R")
if (file.exists(project_settings)) source(project_settings)
