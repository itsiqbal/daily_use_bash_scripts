# Path to the file that tracks the last sync date and user's answer
SYNC_FILE="$HOME/Desktop/projects/iqbal/bash_scripts/.sync_prompt_data"

auto_sync(){
    # Check if the sync file exists
    if [ -f "$SYNC_FILE" ]; then
        # Read the stored date from the file
        read -r stored_date stored_answer < "$SYNC_FILE"
        # Get today's date in YYYY-MM-DD format
        today_date=$(date +"%Y-%m-%d")
        # If the stored date is today's date, skip the prompt
        if [ "$stored_date" = "$today_date" ]; then
            return
        fi
    fi

    # If it's a new day, ask the user whether they want to sync
    echo "Do you want to sync your data today? (y/n)"
    read answer

    # If the user chooses 'y' or 'Y', run the sync commands
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        echo "Syncing data..."
        ~/Desktop/projects/iqbal/bash_scripts/obsidian_notes_sync.sh    # Make sure this script is executable
        
    elif [[ "$answer" == "n" || "$answer" == "N" ]]; then
        echo "Sync skipped for today."
    else
        echo "Invalid input. Please enter 'y' or 'n'."
        exit 1
    fi
    echo "$SYNC_FILE"
    # Write the current date and the user's response to the sync file
    echo "$(date +"%Y-%m-%d") $answer" > "$SYNC_FILE"
}

auto_sync

