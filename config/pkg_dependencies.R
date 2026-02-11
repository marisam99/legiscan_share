# ==============================================================================
# Title:        Package Dependencies
# Description:  Checks for required packages, installs any that are missing,
#               and loads them all. Source this at the top of any script.
# Output:       All packages loaded into the R session
# ==============================================================================

REQUIRED_PACKAGES <- c(
  "tidyverse",    # data manipulation, reading/writing CSVs
  "googledrive",  # downloading data from Google Drive
  "openxlsx2"     # creating and reading Excel workbooks
)

# Check for missing packages
missing_packages <- 
  REQUIRED_PACKAGES[!REQUIRED_PACKAGES %in% installed.packages()[, "Package"]]

# Install missing packages
if (length(missing_packages) > 0) {
  cat("\U0001f7e1 Installing missing packages:", paste(missing_packages, collapse = ", "), "\n")
  install.packages(missing_packages, quiet = TRUE)
}
# Load all packages
invisible(lapply(REQUIRED_PACKAGES, library, character.only = TRUE))
