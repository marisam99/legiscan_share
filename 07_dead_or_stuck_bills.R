# Install and load dplyr if not already done:
# install.packages("dplyr")
library(dplyr)

# 1) Read in your CSV file:
df <- read.csv("filtered_bills.csv", stringsAsFactors = FALSE)

# 2) Define a 'current_date' to measure "stuck" criteria (45+ days of inactivity).
#    For illustration, we use March 26, 2025 (2025-03-26). Adjust as needed.
current_date <- as.Date("2025-03-26")

# 3) Use dplyr to:
#    - Convert status_date to Date type
#    - Check for 'Dead' bills by searching keywords in 'action'
#    - Calculate how many days since last status_date
#    - Categorize each bill with case_when

df <- df %>%
  mutate(
    # Convert status_date to a proper Date (safely handle missing/invalid dates)
    status_date_parsed = as.Date(status_date, format = "%Y-%m-%d"),
    
    # Check if the bill is "Dead" via certain keywords
    is_dead = grepl("died in committee", action, ignore.case = TRUE) |
      grepl("fail|postpone|postponed|inexpedient|killed|veto", 
            action, ignore.case = TRUE),
    
    # Calculate days since last action
    days_since_last_action = as.numeric(difftime(current_date, 
                                                 status_date_parsed, 
                                                 units = "days")),
    
    # Assign status_category with case_when
    status_category = case_when(
      # 1) Dead (based on text in 'action')
      is_dead ~ "Dead",
      
      # 2) Stuck if not Dead and no action > 45 days
      !is_dead & (days_since_last_action > 45) ~ "Stuck",
      
      # 3) Otherwise Active
      TRUE ~ "Active"
    )
  )

# 4) Take a quick look at the counts
table(df$status_category)

# That’s it! 
# You can also filter if you want to see just the Dead or just the Stuck bills, e.g.:
dead_bills  <- df %>% filter(status_category == "Dead")
stuck_bills <- df %>% filter(status_category == "Stuck")
active_bills <- df %>% filter(status_category == "Active")

# Write out your new dataframe if you want:
write.csv(df, "filtered_bills_with_status.csv", row.names = FALSE)
