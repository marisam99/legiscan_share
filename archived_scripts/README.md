# Archived LegiScan API Scripts

## Why These Scripts Are Archived

These scripts (00-04) were used to fetch and process legislative data directly from the LegiScan API. As of February 2026, this workflow has changed:

- **Biko now runs these scripts weekly** to fetch data from the LegiScan API
- **The data is uploaded to Google Drive** for team access
- **Your workflow starts at Script 01** (in the main directory), which downloads the pre-processed data from Google Drive

LegiScan's policy limits API access to one person per organization, so centralizing the API calls through Biko ensures compliance while allowing the team to access the data.

------------------------------------------------------------------------

## Workflow Split

### Biko's Weekly Workflow:
1. Run Scripts 00-04 (these archived scripts) to fetch and process LegiScan data
2. Upload `all_states_combined.csv` to Google Drive

### Your Workflow (Main Directory):
1. **01_download_and_filter.R** - Download from Google Drive and apply filtering
2. **02a_create_tracked_workbook.R** - Create tracked workbook
3. **02b_sync_decisions.R** - Sync decisions from Excel
4. **03_analyze_bills.R** - (Optional) Analyze dead/stuck bills

------------------------------------------------------------------------

## API Key Setup

**Note:** This section is only for the person running the archived scripts (Scripts 00-04). If you're using the main workflow (Scripts 01-03), you do NOT need a LegiScan API key.

This requires a [LegiScan API key](https://legiscan.com/legiscan) to download legislative data.

### Option 1: R Environment File (Recommended)

This method persists your API key across R sessions:

``` r
# Open your .Renviron file
usethis::edit_r_environ()

# Add this line to the file:
LEGISCAN_API_KEY=your_api_key_here

# Save the file and restart R
# Verify it works:
Sys.getenv("LEGISCAN_API_KEY")
```

### Option 2: Set in Current Session

For temporary use in a single session:

``` r
Sys.setenv(LEGISCAN_API_KEY = "your_api_key_here")
```

### Option 3: System Environment Variable

Set it at the system level (persists across all applications):

**macOS/Linux:**

``` bash
# Add to ~/.zshrc or ~/.bashrc
export LEGISCAN_API_KEY="your_api_key_here"

# Reload shell
source ~/.zshrc
```

**Windows:**

``` cmd
setx LEGISCAN_API_KEY "your_api_key_here"
```

### Verifying Your API Key

``` r
# Check if the key is set
api_key <- Sys.getenv("LEGISCAN_API_KEY")
if (nchar(api_key) == 0) {
  stop("API key not found! Please set LEGISCAN_API_KEY environment variable.")
} else {
  message("API key found: ", substr(api_key, 1, 4), "...")
}
```

------------------------------------------------------------------------

## Detailed Script Documentation

### Script 00: `00_simplified_datasetlist_grab.R`

**Purpose:** Fetch the dataset list for all states from the LegiScan API.

**What it does:**
- Queries the LegiScan API for the 2026 legislative session dataset list
- Maps state IDs (1-52) to state abbreviations (includes DC and U.S. Congress)
- Extracts session IDs and access keys needed for downloading bill data

**API Call:**

```
GET https://api.legiscan.com/?key={API_KEY}&op=getDatasetList&year=2026
```

**Output:** `datasetlist2026.csv`

| Column | Description |
|--------|-------------|
| state_id | Numeric state identifier (1-52) |
| state_abbrev | Two-letter state code |
| session_id | LegiScan session identifier |
| access_key | Authentication key for dataset download |
| year_start/year_end | Legislative session years |
| session_name | Full session name |

**Libraries:** `httr2`, `tidyverse`, `jsonlite`

------------------------------------------------------------------------

### Script 01: `01_simplified_get_LegDatasets.R`

**Purpose:** Download and extract bill data for all states with smart caching.

**What it does:**
- Reads session info from `datasetlist2026.csv`
- Implements **smart caching**: compares local dataset hash with remote hash
- Only downloads if the hash has changed (saves bandwidth and time)
- Stores hashes in `dataset_hashes.csv` for comparison
- Downloads base64-encoded ZIP files from LegiScan API
- Extracts JSON bill files to `extracted_data/[STATE]/` directory

**API Call:**

```
GET https://api.legiscan.com/?key={API_KEY}&op=getDataset&id={session_id}&access_key={access_key}
```

**Smart Caching Feature:**

```
First Run:  Downloads all datasets, stores hashes
Next Runs:  Compares hashes → Only downloads changed datasets
```

**Output:**
- `legiscan_zips/legiscan_dataset_[STATE].zip` - Raw ZIP files
- `extracted_data/[STATE]/` - Extracted JSON bill files
- `dataset_hashes.csv` - Hash tracking file

**Libraries:** `httr2`, `jsonlite`, `tidyverse`, `base64enc`

------------------------------------------------------------------------

### Script 02: `02_create_bills_folder.R`

**Purpose:** Standardize the folder structure for bill JSON files.

**What it does:**
- Recursively searches `extracted_data/` for directories named "bill"
- Creates a consistent folder structure in `bill_folder/`
- Copies all bill JSON files to `bill_folder/[STATE]/bill/`

**Why it's needed:** LegiScan's ZIP extracts have nested structures that vary by state. This script normalizes them into a predictable format for downstream processing.

**Input:** `extracted_data/[STATE]/[STATE]/[SESSION]/bill/*.json`

**Output:** `bill_folder/[STATE]/bill/*.json`

**Libraries:** `tidyverse`

------------------------------------------------------------------------

### Script 03: `03_minimal_json_to_csv.R`

**Purpose:** Extract targeted fields from bill JSON files into CSV format.

**What it does:**
- Processes each JSON file in `bill_folder/[STATE]/bill/`
- Extracts only the 10 most relevant columns (not all available fields)
- Handles nested JSON structures (history, committee arrays)
- Creates one CSV per state

**Fields Extracted:**

| Field | Description |
|-------|-------------|
| bill_id | Unique bill identifier |
| bill_number | Legislative bill number (e.g., HB123) |
| title | Short bill title |
| description | Full bill description |
| status | Current bill status code |
| status_date | Date of last status change |
| url | Link to bill on LegiScan |
| action | Semicolon-delimited history of actions |
| importance | Importance ratings from history |
| committee | Comma-delimited committee names |

**Helper Functions:**
- `collapse_history_action()` - Flattens the history array
- `collapse_committee()` - Flattens committee data
- `flatten_bill_targeted()` - Main extraction function

**Output:** `csv_bills/[STATE]_bills.csv`

**Libraries:** `tidyverse`, `jsonlite`

------------------------------------------------------------------------

### Script 04: `04_combine_all_states.R`

**Purpose:** Merge all individual state CSVs into one master dataset.

**What it does:**
- Reads all CSV files from `csv_bills/` directory
- Adds a "state" column to identify the source state
- Selects consistent columns across all states
- Cleans committee column (removes standardized prefixes)

**Columns in Output:** `state`, `bill_id`, `bill_number`, `title`, `description`, `status_date`, `url`, `action`, `committee`

**Output:** `all_states_combined.csv` (~90 MB with all bills)

**Libraries:** `tidyverse`

------------------------------------------------------------------------

## Data Files Generated by Archived Scripts

These files are created when running Scripts 00-04:

| File | Created By | Description |
|------|------------|-------------|
| `datasetlist2026.csv` | Script 00 | State/session metadata |
| `dataset_hashes.csv` | Script 01 | Hash tracking for smart caching |
| `all_states_combined.csv` | Script 04 | All bills from all states (~90 MB) |

| Directory | Created By | Description |
|-----------|------------|-------------|
| `legiscan_zips/` | Script 01 | Downloaded ZIP files from API |
| `extracted_data/` | Script 01 | Extracted JSON bill files |
| `bill_folder/` | Script 02 | Organized bill JSONs by state |
| `csv_bills/` | Script 03 | Per-state CSV files |

------------------------------------------------------------------------

## Customization

### Change Target Year

Edit `00_simplified_datasetlist_grab.R`:

``` r
req_url_query(..., year = 2026)  # Change year
```

------------------------------------------------------------------------

## Requirements for Running Archived Scripts

### R Packages

``` r
install.packages(c(
  "tidyverse",   # Data manipulation
  "httr2",       # HTTP requests
  "jsonlite",    # JSON parsing
  "base64enc"    # Base64 decoding
))
```

### System Requirements

- R version 4.0 or higher
- LegiScan API key (free tier available)
- ~500 MB disk space for full dataset

------------------------------------------------------------------------

## Running These Scripts

If you need to run these archived scripts yourself (e.g., for testing or special circumstances):

1. Set up your LegiScan API key (see API Key Setup above)
2. Move the scripts back to the main directory
3. Run them in sequence:

``` r
source("00_simplified_datasetlist_grab.R")  # Get state session info
source("01_simplified_get_LegDatasets.R")   # Download bill data
source("02_create_bills_folder.R")          # Organize files
source("03_minimal_json_to_csv.R")          # Convert JSON to CSV
source("04_combine_all_states.R")           # Merge all states
```

4. Upload the resulting `all_states_combined.csv` to Google Drive
5. Move the scripts back to `archived_scripts/`

------------------------------------------------------------------------

## Reference

These scripts are kept here for:
- Documentation and reference
- Understanding the complete data pipeline
- Potential future use if workflow changes again
- Troubleshooting data issues
- Understanding where the Google Drive data comes from
