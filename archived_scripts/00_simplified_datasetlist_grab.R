library(httr2)
library(tidyverse)
library(jsonlite)

legiscan_api_key <- Sys.getenv("LEGISCAN_API_KEY")

legiscan_base_url <- "https://api.legiscan.com"

# Create the request
request_url <- request(legiscan_base_url) %>%
  req_url_query(key = legiscan_api_key, op = "getDatasetList", year = 2026)

# Perform the request
legiscan_response <- req_perform(request_url)

# Parse the JSON response body into a list
data <- legiscan_response |> resp_body_json()

# Create a dataframe from the dataset list
datasetlist_df <- bind_rows(data$datasetlist)

# Define state mapping
state_mapping <- data.frame(
  state_number = 1:52,
  state_abbrev = c(
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL",
    "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT",
    "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI",
    "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC", "U.S. Congress"
  )
)


# Add state abbreviations to the dataframe
datasetlist_df <- datasetlist_df |>
  left_join(state_mapping, by = c("state_id" = "state_number"))

datasetlist_df <- datasetlist_df |>
  select(state_id, state_abbrev, everything())

#save the dataset list to a csv file
write_csv(datasetlist_df, "datasetlist2026.csv")


