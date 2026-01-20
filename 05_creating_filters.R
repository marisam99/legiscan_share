# Sample code filtering LegiScan-like data
library(tidyverse)


# create dataframe for combined states
bills_df <- read_csv("all_states_combined.csv")

# Uncomment to define your target states 
# with the state abbreviations in quotation marks (e.g., "CA", "TX", "NY")
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

keywords <- c(
  "education",
  "teacher",
  "school",
  "property tax"
)

#create filtered dataset for keywords
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



# Write the filtered dataframe to a new CSV for use in final product
write_csv(bills_df_filtered, "filtered_bills.csv")
