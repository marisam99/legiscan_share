# Load libraries
library(tidyverse)

# Define the directories
extracted_dir <- "extracted_data"   # Existing dir with your unzipped data
bill_folder   <- "bill_folder"      # New dir to create for organized bills

# 1. Create "bill_folder" if it doesn't exist
if (!dir.exists(bill_folder)) {
  dir.create(bill_folder)
}

# 2. Find all "bill" directories (recursively) under extracted_dir
bill_dirs <- list.dirs(extracted_dir, recursive = TRUE)

# Keep only those directories whose name is literally "bill"
bill_dirs <- bill_dirs[basename(bill_dirs) == "bill"]

# 3. Loop through each "bill" directory
for (bd in bill_dirs) {
  # Example path might be: "extracted_data/CA/CA/2025_something/bill"
  splitted <- strsplit(bd, "/")[[1]]
  
  # The second element is assumed to be the state abbreviation (e.g., "CA")
  # If your structure is different, adjust the index below:
  state_abbrev <- splitted[2]
  
  # 4. Create a matching folder in "bill_folder" 
  #    (so we get "bill_folder/CA/bill")
  new_bill_dir <- file.path(bill_folder, state_abbrev, "bill")
  
  # Create nested directories if they don't exist
  if (!dir.exists(new_bill_dir)) {
    dir.create(new_bill_dir, recursive = TRUE)
  }
  
  # 5. Copy all files from the original "bill" folder to the new "bill" folder
  #    (This should be your JSON files)
  bill_jsons <- list.files(bd, full.names = TRUE)
  
  # Copy them over
  file.copy(bill_jsons, new_bill_dir, overwrite = TRUE)
  
  cat("Copied bill files for state:", state_abbrev, "\n")
}

cat("\nAll 'bill' folders are now copied into:", bill_folder, "\n")
