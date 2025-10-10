#!/bin/bash

# Function to perform git fetch and git pull in a directory
fetch_and_pull() {
  for dir in "$1"/*; do
    if [ -d "$dir" ]; then
      cd "$dir" || continue

      # Check if the directory is a Git repository
      if [ -d ".git" ]; then
        echo "📂 Repo: $(pwd)" | tee -a "$log_file"
        echo "➡️ Fetching latest branches..." | tee -a "$log_file"
        git fetch >> "$log_file" 2>&1 || echo "❌ Failed to fetch in $(pwd)" | tee -a "$log_file"

        echo "➡️ Pulling latest changes..." | tee -a "$log_file"
        git pull >> "$log_file" 2>&1 || echo "❌ Failed to pull in $(pwd)" | tee -a "$log_file"

        echo "✅ Completed: $(pwd)" | tee -a "$log_file"
        echo "" | tee -a "$log_file"
      fi

      # Recursively call the function for subdirectories
      fetch_and_pull "$dir"

      cd ..
    fi
  done
}

# --- Main Script ---
start_dir="$1"

if [ -z "$start_dir" ]; then
  echo "Usage: $0 <directory_path>"
  exit 1
fi

# Verify if the starting directory exists
if [ -d "$start_dir" ]; then
  log_file="$start_dir/update_git_log.txt"   # Log file inside the target directory
  : > "$log_file"                        # Clear the file each time before writing

  echo "🚀 Starting sync from: $start_dir" | tee -a "$log_file"
  echo "🕒 Started at: $(date)" | tee -a "$log_file"
  echo "" | tee -a "$log_file"

  fetch_and_pull "$start_dir"

  echo "" | tee -a "$log_file"
  echo "🎉 All repositories have been updated!" | tee -a "$log_file"
  echo "🕒 Completed at: $(date)" | tee -a "$log_file"
  echo "📄 Log saved at: $log_file"
else
  echo "❌ Directory $start_dir does not exist. Please check the path."
fi
