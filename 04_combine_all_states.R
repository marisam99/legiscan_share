##############################################
#  R SCRIPT: Combine State CSVs into One Dataframe
#  Columns: state, bill_number, title, description,
#           status_date, url, action, committee (last item only)
##############################################

library(tidyverse)

# 1) Directory with your individual state CSVs
csv_dir <- "csv_bills"

# 2) List all CSV files
csv_files <- list.files(csv_dir, pattern = "*.csv", full.names = TRUE)

# 3) Initialize an empty dataframe to row-bind all states
all_states_combined <- data.frame()

# 4) Loop through each CSV
for (file_path in csv_files) {
  
  # Derive state abbreviation from the file name 
  # (e.g., "AL_bills.csv" -> "AL_bills" -> "AL")
  state_abbrev <- tools::file_path_sans_ext(basename(file_path))
  state_abbrev <- gsub("_bills$", "", state_abbrev)
  
  # Read the CSV
  df <- read_csv(file_path, show_col_types = FALSE)
  
  # Add a 'state' column for clarity
  df <- df %>%
    mutate(state = state_abbrev)
  
  # Select only the columns of interest 
  # (make sure your CSVs actually have these columns)
  df <- df %>%
    select(
      state,
      bill_id,
      bill_number,
      title,
      description,
      status_date,
      url,
      action,
      committee
    )
  
  # For 'committee', split by comma and keep only the last item
  df <- df %>%
    mutate(
      committee = as.character(committee),  # Ensure committee is character
      
      # Split the string by commas, remove the first three items, and rejoin
      committee = sapply(
        strsplit(committee, ","), 
        function(x) {
          # If x has fewer than 4 items, returning 
          # the 4th item onward will produce an empty character vector
          # so you'll end up with "".
          rest <- x[4:length(x)]
          
          # Collapse back into a comma-delimited string
          collapsed <- paste(rest, collapse = ",")
          trimws(collapsed)
        }
      )
    )
  
  # Row-bind this state’s data into the master dataframe
  all_states_combined <- bind_rows(all_states_combined, df)
}

##############################################
# Save the Combined Data
##############################################

# save to a new CSV
write_csv(all_states_combined, "all_states_combined.csv")
