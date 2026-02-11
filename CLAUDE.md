# Claude.md TEMPLATE FILE

**Developer Profile:** Dev is an data science analyst that uses programming for data analyses as well as building tools for specific research-related contexts.

-   Programs in R (intermediate to advanced level) and Python (beginner to intermediate level), but has little experience publishing packages or building applications

-   Prioritizes clear documentation, thoughtful UX, and maintainable code over clever solutions

-   Works in a professional research/consulting context (Bellwether) and is comfortable integrating LLM APIs, implementing prompt engineering strategies, and managing technical complexity while keeping interfaces simple for end users.

-   Communication style is direct and professional, favoring concise explanations without excessive jargon, and she expects Claude to match this tone rather than being overly enthusiastic or verbose.

## Personal Preferences

### Communications

1.  Lean toward more plain language when explaining code. The user is familiar with R and Python, but not a regular programmer and has little experience developing full tools or programs. Walk through a new concept step-by-step and explain tool choices/reasoning.
2.  State assumptions explicitly and ask clarifying questions whenever needed; do not make guesses without confirming with the user.
3.  Whenever asked a question, offer alternatives as well as your recommendation and rationale.

### Coding Standards

-   **File Organization:** There will always be at least 2 directories: `config` for constants and settings, and `R` or `python` for functional scripts.. For projects that do data analysis, there will be additional folders for `inputs` and `outputs`. For tool/program development, there will also be a `tests` folder. Use these folders accordingly.

-   **Language Preferences:**

    -   *In R:* Prefer tidyverse functions (including dplyr and \|\> pipes) for data handling

    -   *In Python:* Go with standard PEP8 guidance.

-   **Naming Conventions:** Prefer clarity over brevity, functions that use verb_noun(), and constants in uppercase. Variables should explain themselves without needing comments, be consistent across scripts, and avoid technical jargon.

-   **Code Organization:** Always start new scripts with a header that includes title, description (1-3 sentences), and final output(s) (what the main function returns). Use section dividers and put any configs in the first section, helper functions in the next section, and the main function in a new section. See the example below:

``` R
# ==============================================================================
# Title:        TKTK
# Description:  TKTK
#               TKTK
#               TKTK
#               TKTK
# Output:       TKTK
# ==============================================================================

# Configs ----------------------------------------------------------------------

# Data Cleaning ----------------------------------------------------------------

# Helper Functions -------------------------------------------------------------

# Main Functions ---------------------------------------------------------------
```

-   **Dependency Management:** Prefer centralizing dependencies in one script in the `config` folder, and calling them all with a library().

    -   *In R:* Do not use the package::function notation.

-   **Comments and Inline Documentation:** Be as concise as possible. Use section and subsection headers, as well as inline comments next to the code they are explaining that explain *why*, not what. When creating display messages for processing, completion, and/or success, add color-based emojis to draw users' attention, and ensure the message is user-friendly and actionable. Use `\n` as needed for readability.

### Documentation Standards

There will always be a README.md file, and at minimum it should have these sections:

1.  **Overview**: a short description of the project, the input(s) and output(s), and any special notes. A "NEED TO KNOW" subsection can add more detail within the larger Overview section.

2.  **Quick Start**: step-by-step instructions for getting started, including the package and API prequisites, as well as the actual function call(s).

3.  **Examples**: 1-2 examples of code that showcases the main function of the tool.

4.  **How It Works:** a more detailed section for a more technical audience trying to understand the different design choices made for the project. It will have at least 2 subsections: "Architecture" and "Output Structure," along with any other special notes.

5.  **Configuration:** Any notes about package dependencies or AI model configuration; can also point to a `config/README.md` if used.

6.  **Support:** My contact information for questions and/or concerns.

### Testing Philosophy

-   No need for robust automated tests – I will do manual integration tests myself for step by step debugging, as well as end-to-end tests that use real API calls and examples.

### Git/Version Control Preferences

-   **Commit Message Format:** use past tense describing what was changed; focus on what and why, not how; keep subject line concise but comprehensive.

    -   Example: "Updated \_\_\_\_.R to solve API connection issues + Refactored to use tidyverse"

-   **Safety:** Never commit .env files, API keys, or credentials; never force push to main/master.

-   **Branch-Naming:** Ask the user what the branch should be named before creating it.

-   **Pull Requests:** Never create a PR until requested. In the PR message, include:

    -   a brief (1-2 sentence) summary of what was changed and why

    -   a bullet point list of specific changes made (again, focusing on what and why)

    -   a section listing the files that were changed

    -   this text, on its own line: "Authored alongside Claude Code."

------------------------------------------------------------------------

## Project Context

### Overview

Goal: TKTK Ideal

Output: TKTK

Intended Users: TKTK

**Key Features:**

1.  TKTK

### Technical Stack

TKTK

### Domain Knowledge

TKTK

### Key Constraints

TKTK