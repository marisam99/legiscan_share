# LegiScan Education Finance Bill Tracker

An automated R pipeline for tracking  legislation across U.S. states. This tool downloads legislative bill data from LegiScan's API, processes it through a series of transformation steps, and produces an Excel workbook for human review and decision tracking.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Workflow Overview](#workflow-overview)
- [API Key Setup](#api-key-setup)
- [Detailed Script Documentation](#detailed-script-documentation)
- [Data Files Generated](#data-files-generated)
- [User Workflow: Tracking Bills](#user-workflow-tracking-bills)
- [Customization](#customization)
- [Requirements](#requirements)

---

## Quick Start

### 1. Set up your API key
```r
# In R, add to your .Renviron file:
usethis::edit_r_environ()

# Add this line:
LEGISCAN_API_KEY=your_api_key_here

# Restart R for changes to take effect
```

### 2. Run the pipeline in order
```r
source("00_simplified_datasetlist_grab.R")  # Get state session info
source("01_simplified_get_LegDatasets.R")   # Download bill data
source("02_create_bills_folder.R")          # Organize files
source("03_minimal_json_to_csv.R")          # Convert JSON to CSV
source("04_combine_all_states.R")           # Merge all states
source("05_creating_filters.R")             # Apply keyword/state filters
source("06a_create_tracked_workbook.R")     # Generate Excel workbook
```

### 3. Track bills
1. Open `Master_Pull_List.xlsx`
2. Review the `Needs_Review` sheet
3. Set `Track = TRUE` or `FALSE` for each bill
4. Save and run `source("06b_sync_decisions_from_excel.R")`

---

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DATA ACQUISITION                                 │
├─────────────────────────────────────────────────────────────────────────┤
│  00_simplified_datasetlist_grab.R  →  datasetlist2026.csv               │
│  01_simplified_get_LegDatasets.R   →  extracted_data/[STATE]/bill/*.json│
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         DATA PROCESSING                                  │
├─────────────────────────────────────────────────────────────────────────┤
│  02_create_bills_folder.R   →  bill_folder/[STATE]/bill/*.json          │
│  03_minimal_json_to_csv.R   →  csv_bills/[STATE]_bills.csv              │
│  04_combine_all_states.R    →  all_states_combined.csv                  │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         FILTERING & OUTPUT                               │
├─────────────────────────────────────────────────────────────────────────┤
│  05_creating_filters.R           →  filtered_bills.csv                  │
│  06a_create_tracked_workbook.R   →  Master_Pull_List.xlsx               │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER DECISION LOOP                               │
├─────────────────────────────────────────────────────────────────────────┤
│  User reviews Excel → Sets Track = TRUE/FALSE → Saves file              │
│  06b_sync_decisions_from_excel.R  →  tracking_decisions.csv             │
│  Re-run 06a to refresh workbook                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Abbreviated Script Summary

| Script | Purpose | Output |
|--------|---------|--------|
| `00` | Fetch session IDs from LegiScan API | `datasetlist2026.csv` |
| `01` | Download bill datasets (smart caching) | `extracted_data/` |
| `02` | Standardize folder structure | `bill_folder/` |
| `03` | Extract targeted fields from JSON | `csv_bills/` |
| `04` | Combine all states into one file | `all_states_combined.csv` |
| `05` | Filter by keywords and target states | `filtered_bills.csv` |
| `06a` | Create tracked Excel workbook | `Master_Pull_List.xlsx` |
| `06b` | Sync user decisions back to CSV | `tracking_decisions.csv` |
| `07` | Analyze dead/stuck bills (optional) | `filtered_bills_with_status.csv` |

---

## API Key Setup

This project requires a [LegiScan API key](https://legiscan.com/legiscan) to download legislative data.

### Option 1: R Environment File (Recommended)

This method persists your API key across R sessions:

```r
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

```r
Sys.setenv(LEGISCAN_API_KEY = "your_api_key_here")
```

### Option 3: System Environment Variable

Set it at the system level (persists across all applications):

**macOS/Linux:**
```bash
# Add to ~/.zshrc or ~/.bashrc
export LEGISCAN_API_KEY="your_api_key_here"

# Reload shell
source ~/.zshrc
```

**Windows:**
```cmd
setx LEGISCAN_API_KEY "your_api_key_here"
```

### Verifying Your API Key

```r
# Check if the key is set
api_key <- Sys.getenv("LEGISCAN_API_KEY")
if (nchar(api_key) == 0) {
  stop("API key not found! Please set LEGISCAN_API_KEY environment variable.")
} else {
  message("API key found: ", substr(api_key, 1, 4), "...")
}
```

---

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

---

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

---

### Script 02: `02_create_bills_folder.R`

**Purpose:** Standardize the folder structure for bill JSON files.

**What it does:**
- Recursively searches `extracted_data/` for directories named "bill"
- Creates a consistent folder structure in `bill_folder/`
- Copies all bill JSON files to `bill_folder/[STATE]/bill/`

**Why it's needed:**
LegiScan's ZIP extracts have nested structures that vary by state. This script normalizes them into a predictable format for downstream processing.

**Input:** `extracted_data/[STATE]/[STATE]/[SESSION]/bill/*.json`

**Output:** `bill_folder/[STATE]/bill/*.json`

**Libraries:** `tidyverse`

---

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

---

### Script 04: `04_combine_all_states.R`

**Purpose:** Merge all individual state CSVs into one master dataset.

**What it does:**
- Reads all CSV files from `csv_bills/` directory
- Adds a "state" column to identify the source state
- Selects consistent columns across all states
- Cleans committee column (removes standardized prefixes)

**Columns in Output:**
`state`, `bill_id`, `bill_number`, `title`, `description`, `status_date`, `url`, `action`, `committee`

**Output:** `all_states_combined.csv` (~90 MB with all bills)

**Libraries:** `tidyverse`

---

### Script 05: `05_creating_filters.R`

**Purpose:** Filter the combined dataset to relevant bills.

**What it does:**
- Reads `all_states_combined.csv`
- Applies two-level filtering:

**Keyword Filter** (matches in title, description, or committee):
- "education"
- "teacher"
- "school"
- "property tax"

**State Filter** (17 target states):
- AL, AZ, AR, CA, CO, DE, GA, IN, MD, MI, MS, NM, NY, NC, PA, TN, VA

**Output:** `filtered_bills.csv` (~5 MB)

**Libraries:** `tidyverse`

---

### Script 06a: `06a_create_tracked_workbook.R`

**Purpose:** Generate a multi-sheet Excel workbook for bill tracking with change detection.

**What it does:**
- Loads `filtered_bills.csv` and `tracking_decisions.csv`
- Detects changes since last run:
  - `is_new` - Bills not in previous tracking data
  - `status_changed` - Status date has changed
  - `action_changed` - Bill action has changed
  - `needs_review` - Any of the above are true
- Identifies dead/stuck bills:
  - `is_dead` - Contains keywords like "died in committee", "vetoed", etc.
  - `is_stuck` - No action in 45+ days (and not dead)
- Creates formatted Excel workbook with conditional formatting

**Excel Sheets Created:**

| Sheet | Contents | Styling |
|-------|----------|---------|
| `Needs_Review` | Bills requiring user decision | Blue = new, Yellow = changed |
| `Tracked` | Bills marked Track=TRUE | Standard |
| `Not_Tracked` | Bills marked Track=FALSE | Standard |
| `Archive` | Dead or stuck bills | Gray = dead, Orange = stuck |

**Features:**
- Frozen header rows
- TRUE/FALSE data validation for Track column
- Color-coded highlighting for new/changed bills
- Days since last action calculated

**Configuration:**
```r
CURRENT_DATE = Sys.Date()
STUCK_THRESHOLD_DAYS = 45
```

**Output:**
- `Master_Pull_List.xlsx` (4-sheet workbook)
- Updated `tracking_decisions.csv`

**Libraries:** `tidyverse`, `openxlsx2`

---

### Script 06b: `06b_sync_decisions_from_excel.R`

**Purpose:** Sync user's Track decisions from Excel back to the tracking CSV.

**What it does:**
- Reads `Master_Pull_List.xlsx` (specifically `Needs_Review` sheet)
- Extracts user's Track column values (TRUE/FALSE)
- Updates `tracking_decisions.csv` with:
  - Track decision
  - Decision date
  - Previous status/action for change detection

**Migration Mode (Optional):**
For importing from legacy Excel format with separate sheets:
- Imports from `Tracked_Bills` → Track = TRUE
- Imports from `Do_Not_Track` → Track = FALSE

**Output:** Updated `tracking_decisions.csv`

**Libraries:** `tidyverse`, `openxlsx2`

---

### Script 07: `07_dead_or_stuck_bills.R`

**Purpose:** Analyze and categorize bills by legislative status.

**What it does:**
- Reads `filtered_bills.csv`
- Calculates days since last action
- Categorizes each bill:
  - **Dead** - Contains keywords: "died in committee", "failed", "postponed", "killed", "vetoed"
  - **Stuck** - No action > 45 days and not dead
  - **Active** - All other bills

**Note:** This logic is now integrated into Script 06a, so this script is optional/supplementary.

**Output:** `filtered_bills_with_status.csv`

**Libraries:** `dplyr`

---

## Data Files Generated

The scripts will generate the following files and directories when run:

| File | Created By | Description |
|------|------------|-------------|
| `datasetlist2026.csv` | Script 00 | State/session metadata |
| `dataset_hashes.csv` | Script 01 | Hash tracking for smart caching |
| `all_states_combined.csv` | Script 04 | All bills from all states (~90 MB) |
| `filtered_bills.csv` | Script 05 | Filtered to target states + keywords |
| `tracking_decisions.csv` | Script 06b | User's Track decisions |
| `Master_Pull_List.xlsx` | Script 06a | Excel workbook for tracking |

| Directory | Created By | Description |
|-----------|------------|-------------|
| `legiscan_zips/` | Script 01 | Downloaded ZIP files from API |
| `extracted_data/` | Script 01 | Extracted JSON bill files |
| `bill_folder/` | Script 02 | Organized bill JSONs by state |
| `csv_bills/` | Script 03 | Per-state CSV files |

### Repository Structure

```
legiscan-edfinance-tracker/
├── 00_simplified_datasetlist_grab.R
├── 01_simplified_get_LegDatasets.R
├── 02_create_bills_folder.R
├── 03_minimal_json_to_csv.R
├── 04_combine_all_states.R
├── 05_creating_filters.R
├── 06a_create_tracked_workbook.R
├── 06b_sync_decisions_from_excel.R
├── 07_dead_or_stuck_bills.R
└── README.md
```

**Note:** Data files and directories (CSVs, Excel files, ZIP files, JSON files) are not included in this repository. They will be generated automatically when you run the pipeline scripts.

---

## User Workflow: Tracking Bills

### Initial Setup (First Time)

1. **Configure API key** (see [API Key Setup](#api-key-setup))
2. **Run the full pipeline** (Scripts 00-06a)
3. **Open `Master_Pull_List.xlsx`**

### Regular Workflow

```
1. REFRESH DATA
   └── Run Scripts 00-06a (or just 01-06a if session info hasn't changed)

2. REVIEW BILLS
   └── Open Master_Pull_List.xlsx
   └── Go to "Needs_Review" sheet
   └── Look for highlighted rows:
       • Blue = New bill
       • Yellow = Status or action changed

3. MAKE DECISIONS
   └── Set Track column to TRUE (want to track) or FALSE (ignore)
   └── Save the Excel file

4. SYNC DECISIONS
   └── Run Script 06b to save your decisions to tracking_decisions.csv

5. REFRESH WORKBOOK
   └── Run Script 06a again
   └── Your tracked bills appear in "Tracked" sheet
   └── Ignored bills appear in "Not_Tracked" sheet

6. REPEAT
   └── Run this workflow periodically to catch new bills and changes
```

### Understanding the Excel Sheets

- **Needs_Review**: Your action queue. Bills here are new or have changed.
- **Tracked**: Bills you've decided to follow. Re-run 06a to update.
- **Not_Tracked**: Bills you've decided to ignore. Re-run 06a to update.
- **Archive**: Bills that have died or are stuck (no action in 45+ days).

---

## Customization

### Change Target States

Edit `05_creating_filters.R`:
```r
target_states <- c("AL", "AZ", "AR", ...)  # Modify this list
```

### Change Keywords

Edit `05_creating_filters.R`:
```r
keyword_pattern <- "education|teacher|school|property tax"  # Modify this pattern
```

### Change "Stuck" Threshold

Edit `06a_create_tracked_workbook.R`:
```r
STUCK_THRESHOLD_DAYS <- 45  # Change to your preferred number of days
```

### Change Target Year

Edit `00_simplified_datasetlist_grab.R`:
```r
req_url_query(..., year = 2026)  # Change year
```

---

## Requirements

### R Packages

```r
install.packages(c(
  "tidyverse",   # Data manipulation
  "httr2",       # HTTP requests
  "jsonlite",    # JSON parsing
  "base64enc",   # Base64 decoding
  "openxlsx2"    # Excel file creation
))
```

### System Requirements

- R version 4.0 or higher
- LegiScan API key (free tier available)
- ~500 MB disk space for full dataset

---

## License

This project is for educational and research purposes. LegiScan data is subject to their [terms of service](https://legiscan.com/terms-of-service).

---

## Acknowledgments

- [LegiScan](https://legiscan.com) for providing legislative data API
- Built for tracking legislation across U.S. states
