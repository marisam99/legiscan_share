# LegiScan Education Finance Bill Tracker

An automated R pipeline for tracking legislation across U.S. states. This tool receives legislative bill data from Google Drive (updated weekly from LegiScan's API), applies filtering, and produces an Excel workbook for human review and decision tracking.

**📁 Note:** Scripts 00-04 (LegiScan API data acquisition) have been archived. Your workflow starts at Script 01, which downloads pre-processed data from Google Drive.
- See [`archived_scripts/README.md`](archived_scripts/README.md) for complete documentation on archived scripts, API setup, and the full data pipeline.

------------------------------------------------------------------------

## Table of Contents

-   [Quick Start](#quick-start)
-   [Workflow Overview](#workflow-overview)
-   [Detailed Script Documentation](#detailed-script-documentation)
-   [Data Files Generated](#data-files-generated)
-   [User Workflow: Tracking Bills](#user-workflow-tracking-bills)
-   [Customization](#customization)
-   [Requirements](#requirements)

------------------------------------------------------------------------

## Quick Start {#quick-start}

### 1. Install required packages

``` r
install.packages(c("googledrive", "tidyverse", "openxlsx2"))
```

### 2. Run the pipeline

``` r
source("01_download_and_filter.R")             # Download from Google Drive & filter
source("02a_create_tracked_workbook.R")     # Generate Excel workbook
```

### 3. Track bills

1.  Open `Master_Pull_List.xlsx`
2.  Review the `Needs_Review` sheet
3.  Set `Track = TRUE` or `FALSE` for each bill
4.  Save and run `source("02b_sync_decisions.R")`

**Note:** Scripts 00-04 are no longer needed in your workflow - they are run weekly by your colleague and uploaded to Google Drive. See `archived_scripts/README.md` for details.

------------------------------------------------------------------------

## Workflow Overview {#workflow-overview}

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DATA ACQUISITION (Run by Biko weekly)                 │
├─────────────────────────────────────────────────────────────────────────┤
│  Scripts 00-04 (archived) → all_states_combined.csv → Google Drive      │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                    YOUR WORKFLOW STARTS HERE                             │
├─────────────────────────────────────────────────────────────────────────┤
│  01_download_and_filter.R                                               │
│    • Download gdrive_all_states_combined.csv from Google Drive          │
│    • Apply keyword filters (education, teacher, school, property tax)   │
│    • Apply state filters (17 target states)                             │
│    • Output: filtered_bills.csv                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         EXCEL WORKBOOK CREATION                          │
├─────────────────────────────────────────────────────────────────────────┤
│  02a_create_tracked_workbook.R   →  Master_Pull_List.xlsx               │
│    • Needs_Review sheet (new/changed bills)                             │
│    • Tracked sheet (bills you're tracking)                              │
│    • Not_Tracked sheet (bills you've ignored)                           │
│    • Archive sheet (dead/stuck bills)                                   │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER DECISION LOOP                               │
├─────────────────────────────────────────────────────────────────────────┤
│  User reviews Excel → Sets Track = TRUE/FALSE → Saves file              │
│  02b_sync_decisions.R  →  tracking_decisions.csv                        │
│  Re-run 02a to refresh workbook                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Script Summary

| Script | Purpose | Output |
|-----------------------|--------------------------|-----------------------|
| `00-04` | **ARCHIVED** - Run by colleague weekly | See `archived_scripts/` |
| `01` | Download from Google Drive & filter | `filtered_bills.csv` |
| `02a` | Create tracked Excel workbook | `Master_Pull_List.xlsx` |
| `02b` | Sync user decisions back to CSV | `tracking_decisions.csv` |
| `03` | Analyze dead/stuck bills (optional) | `filtered_bills_with_status.csv` |

------------------------------------------------------------------------

## Detailed Script Documentation {#detailed-script-documentation}

**Note:** For documentation on archived Scripts 00-04, see [`archived_scripts/README.md`](archived_scripts/README.md).

------------------------------------------------------------------------

### Script 01: `01_download_and_filter.R`

**Purpose:** Download combined data from Google Drive and filter to relevant bills.

**What it does:**
- Downloads `gdrive_all_states_combined.csv` from Google Drive (updated weekly by colleague)
- Applies two-level filtering:

**Keyword Filter** (matches in title, description, or committee): - "education" - "teacher" - "school" - "property tax"

**State Filter** (17 target states): - AL, AZ, AR, CA, CO, DE, GA, IN, MD, MI, MS, NM, NY, NC, PA, TN, VA

**Input:** Google Drive file ID `1K1MJ7uB5aXvZLYcq4N8VwjSOFMDkisvd`

**Output:** `filtered_bills.csv` (\~5 MB)

**Libraries:** `googledrive`, `tidyverse`

------------------------------------------------------------------------

### Script 02a: `02a_create_tracked_workbook.R`

**Purpose:** Generate a multi-sheet Excel workbook for bill tracking with change detection.

**What it does:** - Loads `filtered_bills.csv` and `tracking_decisions.csv` - Detects changes since last run: - `is_new` - Bills not in previous tracking data - `status_changed` - Status date has changed - `action_changed` - Bill action has changed - `needs_review` - Any of the above are true - Identifies dead/stuck bills: - `is_dead` - Contains keywords like "died in committee", "vetoed", etc. - `is_stuck` - No action in 45+ days (and not dead) - Creates formatted Excel workbook with conditional formatting

**Excel Sheets Created:**

| Sheet          | Contents                      | Styling                      |
|--------------------|----------------------------|-------------------------|
| `Needs_Review` | Bills requiring user decision | Blue = new, Yellow = changed |
| `Tracked`      | Bills marked Track=TRUE       | Standard                     |
| `Not_Tracked`  | Bills marked Track=FALSE      | Standard                     |
| `Archive`      | Dead or stuck bills           | Gray = dead, Orange = stuck  |

**Features:** - Frozen header rows - TRUE/FALSE data validation for Track column - Color-coded highlighting for new/changed bills - Days since last action calculated

**Configuration:**

``` r
CURRENT_DATE = Sys.Date()
STUCK_THRESHOLD_DAYS = 45
```

**Output:** - `Master_Pull_List.xlsx` (4-sheet workbook) - Updated `tracking_decisions.csv`

**Libraries:** `tidyverse`, `openxlsx2`

------------------------------------------------------------------------

### Script 02b: `02b_sync_decisions.R`

**Purpose:** Sync user's Track decisions from Excel back to the tracking CSV.

**What it does:** - Reads `Master_Pull_List.xlsx` (specifically `Needs_Review` sheet) - Extracts user's Track column values (TRUE/FALSE) - Updates `tracking_decisions.csv` with: - Track decision - Decision date - Previous status/action for change detection

**Migration Mode (Optional):** For importing from legacy Excel format with separate sheets: - Imports from `Tracked_Bills` → Track = TRUE - Imports from `Do_Not_Track` → Track = FALSE

**Output:** Updated `tracking_decisions.csv`

**Libraries:** `tidyverse`, `openxlsx2`

------------------------------------------------------------------------

### Script 03: `03_analyze_bills.R`

**Purpose:** Analyze and categorize bills by legislative status.

**What it does:** - Reads `filtered_bills.csv` - Calculates days since last action - Categorizes each bill: - **Dead** - Contains keywords: "died in committee", "failed", "postponed", "killed", "vetoed" - **Stuck** - No action \> 45 days and not dead - **Active** - All other bills

**Note:** This logic is now integrated into Script 02a, so this script is optional/supplementary.

**Output:** `filtered_bills_with_status.csv`

**Libraries:** `dplyr`

------------------------------------------------------------------------

## Data Files Generated {#data-files-generated}

Your workflow (Scripts 01-03) generates these files:

| File | Created By | Description |
|------|------------|-------------|
| `gdrive_all_states_combined.csv` | Script 01 | Downloaded from Google Drive (updated weekly by colleague) |
| `filtered_bills.csv` | Script 01 | Filtered to target states + keywords |
| `tracking_decisions.csv` | Script 02b | Your Track decisions |
| `Master_Pull_List.xlsx` | Script 02a | Excel workbook for tracking |
| `filtered_bills_with_status.csv` | Script 03 | (Optional) Bills categorized by status |

**Note:** For information about files generated by archived Scripts 00-04, see [`archived_scripts/README.md`](archived_scripts/README.md).

### Repository Structure

```
legiscan-edfinance-tracker/
├── archived_scripts/
│   ├── 00_simplified_datasetlist_grab.R
│   ├── 01_simplified_get_LegDatasets.R
│   ├── 02_create_bills_folder.R
│   ├── 03_minimal_json_to_csv.R
│   ├── 04_combine_all_states.R
│   └── README.md
├── 01_download_and_filter.R
├── 02a_create_tracked_workbook.R
├── 02b_sync_decisions.R
├── 03_analyze_bills.R
└── README.md
```

**Note:**
- Scripts 00-04 are archived (run weekly by colleague, not by you)
- Data files (CSVs, Excel files) are generated when you run Scripts 05-06a

------------------------------------------------------------------------

## User Workflow: Tracking Bills {#user-workflow-tracking-bills}

### Initial Setup (First Time)

1.  **Install required packages:** `install.packages(c("googledrive", "tidyverse", "openxlsx2"))`
2.  **Run Script 05** to download and filter data: `source("01_download_and_filter.R")`
3.  **Run Script 02a** to create workbook: `source("02a_create_tracked_workbook.R")`
4.  **Open `Master_Pull_List.xlsx`**

### Regular Workflow

```
1. REFRESH DATA
   └── Run Script 05: source("01_download_and_filter.R")
   └── Run Script 02a: source("02a_create_tracked_workbook.R")

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
   └── Run Script 02b to save your decisions to tracking_decisions.csv

5. REFRESH WORKBOOK
   └── Run Script 02a again
   └── Your tracked bills appear in "Tracked" sheet
   └── Ignored bills appear in "Not_Tracked" sheet

6. REPEAT
   └── Run this workflow weekly after your colleague updates Google Drive
```

### Understanding the Excel Sheets

-   **Needs_Review**: Your action queue. Bills here are new or have changed.
-   **Tracked**: Bills you've decided to follow. Re-run 02a to update.
-   **Not_Tracked**: Bills you've decided to ignore. Re-run 02a to update.
-   **Archive**: Bills that have died or are stuck (no action in 45+ days).

------------------------------------------------------------------------

## Customization {#customization}

### Change Target States

Edit `01_download_and_filter.R`:

``` r
target_states <- c("AL", "AZ", "AR", ...)  # Modify this list
```

### Change Keywords

Edit `01_download_and_filter.R`:

``` r
keyword_pattern <- "education|teacher|school|property tax"  # Modify this pattern
```

### Change "Stuck" Threshold

Edit `02a_create_tracked_workbook.R`:

``` r
STUCK_THRESHOLD_DAYS <- 45  # Change to your preferred number of days
```

------------------------------------------------------------------------

## Requirements {#requirements}

### R Packages

``` r
install.packages(c(
  "googledrive", # Google Drive access
  "tidyverse",   # Data manipulation
  "openxlsx2"    # Excel file creation
))
```

**Note:** Packages `httr2`, `jsonlite`, and `base64enc` are only needed if running archived scripts (00-04).

### System Requirements

-   R version 4.0 or higher
-   Google account with access to shared Google Drive file
-   \~50 MB disk space for filtered data

------------------------------------------------------------------------

## License

This project is for educational and research purposes. LegiScan data is subject to their [terms of service](https://legiscan.com/terms-of-service).

------------------------------------------------------------------------

## Acknowledgments

-   [LegiScan](https://legiscan.com) for providing legislative data API
-   Built for tracking legislation across U.S. states