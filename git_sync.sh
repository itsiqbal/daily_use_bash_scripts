#!/bin/bash

# Function to perform git fetch and git pull in a directory
fetch_and_pull() {
  for dir in "$1"/*; do
    if [ -d "$dir" ]; then
      cd "$dir" || continue

      # Check if the directory is a Git repository
      if [ -d ".git" ]; then
        echo "Fetching latest branches in $(pwd)..."
        git fetch || echo "Failed to fetch in $(pwd)"

        echo "Pulling latest changes in $(pwd)..."
        git pull || echo "Failed to pull in $(pwd)"
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
  echo "Starting from: $start_dir"
  fetch_and_pull "$start_dir"
  echo "All repositories have been updated!"
else
  echo "Directory $start_dir does not exist. Please check the path."
fi
