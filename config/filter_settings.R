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

TARGET_STATES <- c(
  "AL", "AZ", "AR", "CA", "CO", "DE", "GA", "IN",
  "MD", "MI", "MS", "NM", "NY", "NC", "PA", "TN", "VA"
)

KEYWORDS <- c("education", "teacher", "school", "property tax")

# Analysis Thresholds ----------------------------------------------------------

STUCK_THRESHOLD_DAYS <- 45
DEAD_KEYWORDS <- "died in committee|fail|postpone|postponed|inexpedient|killed|veto"

# Sync Settings ----------------------------------------------------------------

# Set TRUE to import from old Excel structure (Tracked_Bills / Do_Not_Track)
MIGRATION_MODE <- FALSE
