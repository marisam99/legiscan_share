# Sample code filtering LegiScan-like data
library(tidyverse)


# create dataframe for combined states
bills_df <- read_csv("all_states_combined.csv")

with this: 
library(googledrive)
library(tidyverse)

# Download from Google Drive
drive_download(
  as_id("1K1MJ7uB5aXvZLYcq4N8VwjSOFMDkisvd"),
  path = "gdrive_all_states_combined.csv",
  overwrite = TRUE)

# Read the CSV
bills_df <- read_csv("gdrive_all_states_combined.csv")