# ==============================================================================
# Title:        Analyze Dead or Stuck Bills
# Description:  Categorizes filtered bills as Dead, Stuck, or Active based on
#               legislative action keywords and days since last action. Bills
#               inactive for 45+ days are flagged as Stuck.
# Output:       filtered_bills_with_status.csv
# ==============================================================================

source("config/pkg_dependencies.R")
source("config/filter_settings.R")

# CONFIGS & CONSTANTS ------------------------------------------------------------

CURRENT_DATE <- Sys.Date()

# 1. Read in CSV file -------------------------------------------------------------------------

cat("\n\U0001f535 Loading bills from", "filtered_bills.csv", "...\n")
bills <- read_csv("filtered_bills.csv", show_col_types = FALSE)
cat("  Loaded", nrow(bills), "bills\n")

# 2. Check for dead or stuck bills
bills <- bills |>
  mutate(
    # convert status_date to a proper Date (safely andle missing/invalid dates)
    status_date_parsed = as.Date(status_date, format = "%Y-%m-%d"),

    # Check if the bill is "Dead"  via certain keywords
    is_dead = grepl(DEAD_KEYWORDS, action, ignore.case = TRUE),
    
    # Calculate days since last action
    days_since_last_action = as.numeric(difftime(CURRENT_DATE, status_date_parsed, units = "days")),
    
    # Assign status_category
    status_category = case_when(
      is_dead ~ "Dead", # assigned 'dead' status based on text in 'action'
      !is_dead & (days_since_last_action > STUCK_THRESHOLD_DAYS) ~ "Stuck", # assigned 'stuck' if not Dead and not action > 45 days
      TRUE ~ "Active" # otherwise active
    )
  )

# Summary ----------------------------------------------------------------------

counts <- table(bills$status_category)
cat("\n\U0001f4ca Bill Status Summary:\n")
for (category in names(counts)) {
  cat("  ", category, ":", counts[category], "\n")
}

dead_bills <- bills |> filter(status_category == "Dead")
stuck_bills <- bills |> filter(status_category == "Stuck")
active_bills <- bills |> filter(status_category == "Active")

write_csv(bills, "filtered_bills_with_status.csv")
cat("\n\U0001f7e2 Wrote", nrow(bills), "bills with status categories to", "filtered_bills_with_status.csv", "\n\n")
