#!/bin/bash
# chmod +x ./.git_sync.sh

# Add this to ~/.zshrc or ~/.bash_profile
notes_stash_and_sync() {
    # Check if the directory exists
    if [ ! -d "$start_dir" ]; then
        echo "Directory $start_dir does not exist. Please provide a valid directory." | tee -a "$LOG_FILE"
        return 1
    fi

    # Change to the start directory
    cd "$start_dir" || { echo "Failed to navigate to $start_dir"; return 1; }

    # Log file location
    local LOG_FILE="${start_dir}/.git_sync.log"
    echo "Starting sync in $start_dir" | tee -a "$LOG_FILE"
    echo "Starting sync at $(date)" | tee -a "$LOG_FILE"

    # Ensure the directory is a Git repository
    if [ ! -d ".git" ]; then
        echo "Directory $start_dir is not a Git repository." | tee -a "$LOG_FILE"
        return 1
    fi

    # Stash changes if any, and pull with rebase
    if ! git diff-index --quiet HEAD --; then
        echo "Stashing local changes..." | tee -a "$LOG_FILE"
        git stash push -m "Auto stash before sync" --keep-index
    fi

    # Attempt to pull with rebase, retry on failure
    until git pull --rebase --autostash origin main; do
        echo "Network or rebase error. Retrying in 5 minutes..." | tee -a "$LOG_FILE"
        sleep 5m
    done

    # Pop stash if it was created
    if git stash list | grep -q "Auto stash before sync"; then
        echo "Applying stashed changes..." | tee -a "$LOG_FILE"
        git stash pop || { echo "Conflict during stash pop. Please resolve manually." | tee -a "$LOG_FILE"; return 1; }
    fi

    # Check for uncommitted changes before committing
    if ! git diff-index --quiet HEAD -- || [ -n "$(git ls-files --others --exclude-standard)" ]; then
        # Add all changes, including untracked files
        echo "Adding changes to staging, including untracked files..." | tee -a "$LOG_FILE"
        git add --all

        # Debugging: Confirm staged changes
        echo "Staged changes:" | tee -a "$LOG_FILE"
        git status | tee -a "$LOG_FILE"

        # Get the current date in YYYY-MM-DD format
        local current_date
        current_date=$(date +"%Y-%m-%d")

        # Commit with message including current date
        echo "Committing changes..." | tee -a "$LOG_FILE"
        git commit -m "obsidian sync - $current_date"

        # Push changes, retry on network failure
        until git push origin main; do
            echo "Push failed. Retrying in 5 minutes..." | tee -a "$LOG_FILE"
            sleep 5m
        done
        echo "Changes committed and pushed successfully." | tee -a "$LOG_FILE"
    else
        echo "No changes to commit." | tee -a "$LOG_FILE"
    fi

    # Drop all the previous stashes to avoid issues
    echo "Cleaning all the local stashes..." | tee -a "$LOG_FILE"
    git stash clear

    echo "Sync completed for $start_dir at $(date)" | tee -a "$LOG_FILE"
}


# Set the starting directory
start_dir="${1:-$HOME/Desktop/projects/iqbal/iqbal-notes/}"

# Verify if the starting directory exists
if [ -d "$start_dir" ]; then
  notes_stash_and_sync "$start_dir"
else
  echo "Directory $start_dir does not exist. Please check the path."
fi
