#!/bin/bash

# Log file
LOG_FILE="${HOME}/git_sync.log"

# Function to log messages
log() {
  echo "$1" | tee -a "$LOG_FILE"
}

# Function to perform git operations in a directory
fetch_and_pull() {
  for dir in "$1"/*; do
    if [ -d "$dir" ]; then
      cd "$dir" || continue

      # Check if the directory is a Git repository
      if [ -d ".git" ]; then
        log "Processing repository: $(pwd)"

        # Attempt to checkout the main branch
        if git branch --list main >/dev/null 2>&1; then
          log "Switching to the 'main' branch..."
          git checkout main || log "Failed to switch to 'main' in $(pwd)"
        else
          log "No 'main' branch found in $(pwd). Skipping branch switch."
        fi

        # Fetch the latest branches
        log "Fetching latest branches in $(pwd)..."
        git fetch || log "Failed to fetch in $(pwd)"

        # Pull the latest changes
        log "Pulling latest changes in $(pwd)..."
        git pull --rebase || log "Failed to pull in $(pwd)"
      fi

      # Recursively call the function for subdirectories
      fetch_and_pull "$dir"

      # Go back to the parent directory
      cd ..
    fi
  done
}

# Set the starting directory
start_dir="${1:-$HOME/Desktop/projects/work/}"

# Verify if the starting directory exists
if [ -d "$start_dir" ]; then
  log "Starting from: $start_dir"
  fetch_and_pull "$start_dir"
  log "All repositories have been updated!"
else
  log "Directory $start_dir does not exist. Please check the path."
fi