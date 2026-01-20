##############################################
#  R SCRIPT: Download and Unzip LegiScan Data
#  Modified to Skip Re-Download if dataset_hash is unchanged
##############################################

library(httr2)
library(jsonlite)
library(tidyverse)
library(base64enc)

# 1) Read in the CSV containing session_id and access_key
datasetlist_data <- read_csv("datasetlist2026.csv")


# 2) LegiScan API credentials
legiscan_api_key <- Sys.getenv("LEGISCAN_API_KEY")
legiscan_base_url <- "https://api.legiscan.com"

# 3) Create a local data frame to store known hashes
#    We'll keep them in a CSV so we can see which sessions changed next time.
hash_record_file <- "dataset_hashes.csv"

# Attempt to read existing hashes:
if (file.exists(hash_record_file)) {
  stored_hashes <- read_csv(hash_record_file, show_col_types = FALSE)
} else {
  # or create an empty tibble if none exists
  stored_hashes <- tibble(
    session_id = integer(),
    dataset_hash = character()
  )
}

# 4) Loop over each row in df_filtered
for (i in seq_len(nrow(datasetlist_data))) {
  
  row_info       <- datasetlist_data[i, ]
  state_id_num   <- row_info$state_id
  state_abbrev   <- row_info$state_abbrev
  session_id     <- row_info$session_id
  access_key     <- row_info$access_key
  remote_hash    <- row_info$dataset_hash  # from datasetlist2025.csv
  
  cat("\nProcessing state:", state_abbrev, "(ID:", state_id_num, "), session_id:", session_id, "\n")
  
  # 5) Compare with local stored hash
  local_hash_row <- stored_hashes %>%
    filter(session_id == session_id)
  
  if (nrow(local_hash_row) == 1 && local_hash_row$dataset_hash[[1]] == remote_hash) {
    cat("No change in dataset_hash; skipping download.\n")
    next
  }
  
  cat("Hash changed or missing; downloading ZIP...\n")
  
  # 6) Create the request for getDataset
  get_data_request <- request(legiscan_base_url) %>%
    req_url_query(
      key        = legiscan_api_key,
      op         = "getDataset",
      id         = session_id,
      access_key = access_key
    )
  
  # Perform the request
  response <- req_perform(get_data_request)
  
  # Parse the JSON response
  parsed_response <- response |> resp_body_json()
  
  # Extract the base64-encoded ZIP archive
  encoded_zip <- parsed_response$dataset$zip
  # Decode from base64 -> raw bytes
  decoded_zip <- base64decode(encoded_zip)
  
  # Create or confirm a folder to store the ZIP files
  zips_dir <- "legiscan_zips"
  if (!dir.exists(zips_dir)) {
    dir.create(zips_dir)
  }
  
  # Create a unique path for writing the ZIP file
  zip_path <- file.path(zips_dir, paste0("legiscan_dataset_", state_abbrev, ".zip"))
  
  # Write the ZIP file 
  writeBin(decoded_zip, zip_path)
  
  # Create an extraction directory for this state
  extract_dir <- file.path("extracted_data", state_abbrev)
  if (!dir.exists(extract_dir)) {
    dir.create(extract_dir, recursive = TRUE)
  }
  
  # Unzip
  unzip(zip_path, exdir = extract_dir)
  
  # 7) Update / add the new hash in stored_hashes
  stored_hashes <- stored_hashes %>%
    filter(session_id != session_id) %>%  # remove any old entry
    bind_rows(
      tibble(session_id = session_id, dataset_hash = remote_hash)
    )
  
  cat("Saved/unzipped dataset for", state_abbrev, "and updated local hash.\n")
}

# 8) Write back the updated hashes
write_csv(stored_hashes, hash_record_file)

cat("\nAll target states processed.\n")
