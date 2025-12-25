#!/usr/bin/env python3

import os
import re
from pathlib import Path

# --- Configuration ---
ZDOTDIR = os.getenv('ZDOTDIR')
ZDOTDIR = Path(ZDOTDIR) if ZDOTDIR else Path.home()
# 1. Path to your history file
HISTORY_FILE = ZDOTDIR / ".zsh_history"

# 2. Path for the cleaned output file
OUTPUT_FILE = ZDOTDIR / ".zsh_history_cleaned"

# 3. (Brainstormed Rule) Remove trivial or personal alias commands
# Add any commands you want to automatically remove
FILTERED_COMMANDS = {
    # Trivial commands
    "ls",
    "ll",
    "la",
    "l",
    "cd",       # Catches 'cd' by itself
    "cd ..",    # Catches 'cd ..'
    "..",
    "pwd",
    "clear",
    "exit",
    "history",
    "bg",
    "fg",
    "true",
    # Personal aliases from your examples
    "pni",
    "npk",
    "groh",
    "gst",
    "gvw",
    "pnab",
}

# 4. (Rule #3) Regex to detect secrets or tokens
SECRET_RE = re.compile(
    r"""
    (
        # Common prefixes for tokens
        (ghp|ghs|ghr|glpat-)[a-zA-Z0-9_-]{20,} | # GitHub, GitLab
        (sk_live|pk_live|rk_live|sk_test|pk_test|rk_test)_[a-zA-Z0-9]{20,} | # Stripe
        (xoxp|xoxb|xapp-)[a-zA-Z0-9-]{20,} | # Slack
        (key|token|secret|password|passwd) # Keywords
    )
    |
    (
        # Generic high-entropy strings (long alphanumeric/base64-like)
        # Tweak {40,} to be more or less aggressive
        [a-zA-Z0-9/+=]{40,}
    )
""",
    re.VERBOSE | re.IGNORECASE,
)

# 5. (Brainstormed Rule) Regex to detect PII (like home dirs)
# This will remove commands that reference user-specific paths
PII_PATH_RE = re.compile(r"/home/|/Users/")

# 6. Maximum command length (remove commands longer than this)
MAX_COMMAND_LENGTH = 250  # Adjust this value as needed

# 7. (Rule #1) Regex to validate a standard zsh history entry
# This automatically filters out junk (like '?? ...') and continuations
HISTORY_ENTRY_RE = re.compile(r"^: \d+:\d+;(.*)$")

# --- Script Logic ---


def clean_history():
    if not HISTORY_FILE.exists():
        print(f"❌ Error: History file not found at {HISTORY_FILE}")
        return

    seen_commands = set()
    clean_lines = []
    total_lines = 0
    removed_lines = 0

    # Counters for why lines were removed
    reason_counts = {
        "junk": 0,
        "trivial": 0,
        "hidden": 0,
        "secret": 0,
        "multiline": 0,
        "pii": 0,
        "duplicate": 0,
        "too_long": 0,
        "cd_commands": 0,  # <-- NEW: Counter for 'cd ...' commands
    }

    print(f"🧹 Starting cleanup of {HISTORY_FILE}...")

    try:
        with open(HISTORY_FILE, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except Exception as e:
        print(f"❌ Error reading file {HISTORY_FILE}: {e}")
        return

    for line in lines:
        total_lines += 1

        # Rule #1: Remove multi-line entries & junk
        match = HISTORY_ENTRY_RE.match(line.strip())
        if not match:
            removed_lines += 1
            reason_counts["junk"] += 1
            continue  # Skip junk or multi-line continuations

        command = match.group(1)
        command_stripped = command.strip()

        # (Brainstormed Rule) Remove trivial/alias commands
        if command_stripped in FILTERED_COMMANDS:
            removed_lines += 1
            reason_counts["trivial"] += 1
            continue

        # *** NEW RULE: Remove all commands starting with 'cd ' ***
        # This catches 'cd /some/dir', 'cd ~/projects', etc.
        if command_stripped.startswith("cd "):
            removed_lines += 1
            reason_counts["cd_commands"] += 1
            continue

        # (Brainstormed Rule) Remove commands starting with space (hidden from history)
        if command.startswith(" "):
            removed_lines += 1
            reason_counts["hidden"] += 1
            continue

        # Rule #3: Remove entries with secrets/tokens
        if SECRET_RE.search(command):
            print(f"    - Removing potential secret: {command[:70]}...")
            removed_lines += 1
            reason_counts["secret"] += 1
            continue

        # (Brainstormed Rule) Remove commands with user paths
        if PII_PATH_RE.search(command):
            print(f"    - Removing potential PII (user path): {command[:70]}...")
            removed_lines += 1
            reason_counts["pii"] += 1
            continue

        # (Brainstormed Rule) Remove excessively long commands
        # This was already in your script
        if len(command) > MAX_COMMAND_LENGTH:
            print(
                f"    - Removing long command ({len(command)} chars): {command[:70]}..."
            )
            removed_lines += 1
            reason_counts["too_long"] += 1
            continue

        # (Rule #1, part 2) Remove commands that start a multi-line entry
        if command.rstrip().endswith("\\"):
            removed_lines += 1
            reason_counts["multiline"] += 1
            continue

        # Rule #2 & #4: Remove duplicates
        if command_stripped in seen_commands:
            removed_lines += 1
            reason_counts["duplicate"] += 1
            continue

        # If all checks pass, keep the line
        seen_commands.add(command_stripped)
        clean_lines.append(line)  # Append the *original* line with timestamp

    print("\n✅ Cleanup complete.")
    print(f"    - Read:        {total_lines:8} lines")
    print(f"    - Kept:        {len(clean_lines):8} lines")
    print(f"    - Removed:     {removed_lines:8} lines")
    print(f"        - Duplicates:      {reason_counts['duplicate']}")
    print(
        f"        - Multi-line/Junk: {reason_counts['junk'] + reason_counts['multiline']}"
    )
    print(f"        - Trivial/Aliases: {reason_counts['trivial']}")
    print(f"        - 'cd' commands:   {reason_counts['cd_commands']}") # <-- NEW: Report
    print(f"        - Secrets:         {reason_counts['secret']}")
    print(f"        - PII (User Paths):{reason_counts['pii']}")
    print(f"        - Hidden (Space):  {reason_counts['hidden']}")
    print(
        f"        - Too Long (>{MAX_COMMAND_LENGTH} chars): {reason_counts['too_long']}"
    )

    # Write the cleaned content to the new file
    try:
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            f.writelines(clean_lines)
        print(f"\n💾 Successfully wrote cleaned history to: {OUTPUT_FILE}")
        print("\n👉 To use it, first inspect the file, then run:")
        print(f"    less {OUTPUT_FILE}")
        print(f"    mv {OUTPUT_FILE} {HISTORY_FILE}")
    except IOError as e:
        print(f"\n❌ Error writing to output file {OUTPUT_FILE}: {e}")


if __name__ == "__main__":
    clean_history()