# Script 01: Download from Google Drive and filter bills
# Data source: Google Drive (updated weekly by colleague from LegiScan API)
library(googledrive)
library(tidyverse)

# Download from Google Drive
drive_download(
  as_id("1K1MJ7uB5aXvZLYcq4N8VwjSOFMDkisvd"),
  path = "gdrive_all_states_combined.csv",
  overwrite = TRUE)

# Read the CSV
bills_df <- read_csv("gdrive_all_states_combined.csv")

# Define target states (17 states tracking education/finance legislation)
target_state_ids <- c("AL",
                      "AZ",
                      "AR",
                      "CA",
                      "CO",
                      "DE",
                      "GA",
                      "IN",
                      "MD",
                      "MI",
                      "MS",
                      "NM",
                      "NY",
                      "NC",
                      "PA",
                      "TN",
                      "VA")

# Define keywords to search for
keywords <- c(
  "education",
  "teacher",
  "school",
  "property tax"
)

# Filter bills by keywords and target states
bills_df_filtered <- bills_df %>%
  filter(
    # (1) Check if the title has ANY match with your keywords
    map_lgl(title, ~ any(str_detect(tolower(.x), keywords))) |

      # (2) OR if the description has ANY match with your keywords
      map_lgl(description, ~ any(str_detect(tolower(.x), keywords))) |

      # (3) OR if the committee name has ANY match with your keywords
      map_lgl(committee, ~ any(str_detect(tolower(.x), keywords)))
  ) |>
  # filter for target states
  filter(state %in% target_state_ids)

# Write the filtered dataframe to a new CSV for use in downstream scripts
write_csv(bills_df_filtered, "filtered_bills.csv")
