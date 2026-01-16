#!/usr/bin/env bash
#
# Git Sync Utility - UI Library
# User interface functions for prompts, formatting, and output
#

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Log levels
log_debug() {
    [[ "${LOG_LEVEL:-info}" == "debug" ]] && echo -e "${DIM}[DEBUG]${NC} $*" >&2
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Print banner
print_banner() {
    cat <<'EOF'
╔═══════════════════════════════════════════════════════╗
║              Git Sync Utility v1.0                    ║
║          End-of-Day Repository Backup Tool            ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo ""
}

# Print section header
print_header() {
    local title="$1"
    echo -e "${BOLD}${CYAN}═══ ${title} ═══${NC}"
}

# Print repository header
print_repo_header() {
    local repo_name="$1"
    local branch="$2"
    echo -e "${BOLD}${MAGENTA}📦 ${repo_name}${NC} ${DIM}(branch: ${branch})${NC}"
}

# Print separator line
print_separator() {
    printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '─'
}

# Prompt for yes/no confirmation
# Returns 0 for yes, 1 for no
confirm_proceed() {
    local prompt="$1"
    local response
    
    while true; do
        read -rp "$(echo -e "${YELLOW}${prompt}${NC} [y/N]: ")" response
        case "${response,,}" in
            y|yes)
                return 0
                ;;
            n|no|"")
                return 1
                ;;
            *)
                echo "Please answer 'y' or 'n'"
                ;;
        esac
    done
}

# Prompt for action selection
# Usage: prompt_action "What to do?" "a:Add all" "i:Interactive" "s:Skip"
# Returns: The key of selected option (e.g., "a", "i", "s")
prompt_action() {
    local prompt="$1"
    shift
    local -a options=("$@")
    
    echo -e "${CYAN}${prompt}${NC}"
    
    # Print options
    for opt in "${options[@]}"; do
        local key="${opt%%:*}"
        local desc="${opt#*:}"
        echo -e "  ${GREEN}[${key}]${NC} ${desc}"
    done
    
    # Get valid keys
    local valid_keys=""
    for opt in "${options[@]}"; do
        valid_keys+="${opt%%:*}"
    done
    
    # Prompt for selection
    local response
    while true; do
        read -rp "> " response
        response="${response,,}"
        
        if [[ "$valid_keys" == *"$response"* ]]; then
            echo "$response"
            return 0
        else
            echo -e "${RED}Invalid choice. Please select from [${valid_keys}]${NC}"
        fi
    done
}

# Prompt for text input with default
# Usage: prompt_input "Commit message" "default value"
# Returns: User input or default
prompt_input() {
    local prompt="$1"
    local default="$2"
    local response
    
    if [[ -n "$default" ]]; then
        read -rp "$(echo -e "${CYAN}${prompt}${NC} [${DIM}${default}${NC}]: ")" response
        echo "${response:-$default}"
    else
        read -rp "$(echo -e "${CYAN}${prompt}:${NC} ")" response
        echo "$response"
    fi
}

# Show Git status in formatted output
show_git_status() {
    local -a staged_files=()
    local -a modified_files=()
    local -a untracked_files=()
    
    # Get staged files
    while IFS= read -r file; do
        staged_files+=("$file")
    done < <(git diff --cached --name-only 2>/dev/null)
    
    # Get modified files
    while IFS= read -r file; do
        modified_files+=("$file")
    done < <(git diff --name-only 2>/dev/null)
    
    # Get untracked files
    while IFS= read -r file; do
        untracked_files+=("$file")
    done < <(git ls-files --others --exclude-standard 2>/dev/null)
    
    # Display status
    if [[ ${#staged_files[@]} -gt 0 ]]; then
        echo -e "${GREEN}Staged files (${#staged_files[@]}):${NC}"
        printf '  %s\n' "${staged_files[@]}" | head -10
        [[ ${#staged_files[@]} -gt 10 ]] && echo "  ... and $((${#staged_files[@]} - 10)) more"
    fi
    
    if [[ ${#modified_files[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Modified files (${#modified_files[@]}):${NC}"
        printf '  %s\n' "${modified_files[@]}" | head -10
        [[ ${#modified_files[@]} -gt 10 ]] && echo "  ... and $((${#modified_files[@]} - 10)) more"
    fi
    
    if [[ ${#untracked_files[@]} -gt 0 ]]; then
        echo -e "${BLUE}Untracked files (${#untracked_files[@]}):${NC}"
        printf '  %s\n' "${untracked_files[@]}" | head -10
        [[ ${#untracked_files[@]} -gt 10 ]] && echo "  ... and $((${#untracked_files[@]} - 10)) more"
    fi
    
    # Show unpushed commits if any
    local unpushed_count
    unpushed_count=$(git log @{u}.. --oneline 2>/dev/null | wc -l || echo 0)
    if [[ $unpushed_count -gt 0 ]]; then
        echo ""
        echo -e "${MAGENTA}Unpushed commits (${unpushed_count}):${NC}"
        git log @{u}.. --oneline 2>/dev/null | head -5
        [[ $unpushed_count -gt 5 ]] && echo "  ... and $((unpushed_count - 5)) more"
    fi
}

# Progress indicator for long operations
# Usage: show_spinner "Processing..." & spinner_pid=$!; long_operation; kill $spinner_pid
show_spinner() {
    local message="$1"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while true; do
        i=$(( (i+1) % ${#spin} ))
        printf "\r${CYAN}${spin:$i:1} ${message}${NC}"
        sleep 0.1
    done
}

# Print a box around text
print_box() {
    local text="$1"
    local len=${#text}
    local border_len=$((len + 4))
    
    printf '┌%*s┐\n' "$border_len" '' | tr ' ' '─'
    printf '│  %s  │\n' "$text"
    printf '└%*s┘\n' "$border_len" '' | tr ' ' '─'
}

# Print success message with checkmark
print_success_msg() {
    echo -e "${GREEN}✓${NC} $*"
}

# Print error message with cross
print_error_msg() {
    echo -e "${RED}✗${NC} $*"
}

# Print warning message with exclamation
print_warn_msg() {
    echo -e "${YELLOW}⚠${NC} $*"
}

# Print info message with bullet
print_info_msg() {
    echo -e "${BLUE}•${NC} $*"
}

# Show progress bar
# Usage: show_progress_bar 30 100 "Processing"
show_progress_bar() {
    local current=$1
    local total=$2
    local message="${3:-Progress}"
    local width=50
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${message}: ["
    printf "%${filled}s" '' | tr ' ' '█'
    printf "%${empty}s" '' | tr ' ' '░'
    printf "] %3d%%" "$percentage"
    
    [[ $current -eq $total ]] && echo ""
}

# Clear current line (useful for replacing spinner/progress)
clear_line() {
    printf '\r%*s\r' "${COLUMNS:-80}" ''
}

# Ask for file selection from list
# Usage: select_file "file1" "file2" "file3"
# Returns: Selected filename
select_file() {
    local -a files=("$@")
    
    if [[ ${#files[@]} -eq 0 ]]; then
        log_error "No files to select from"
        return 1
    fi
    
    if [[ ${#files[@]} -eq 1 ]]; then
        echo "${files[0]}"
        return 0
    fi
    
    echo -e "${CYAN}Select a file:${NC}"
    select file in "${files[@]}" "Cancel"; do
        if [[ "$file" == "Cancel" ]]; then
            return 1
        elif [[ -n "$file" ]]; then
            echo "$file"
            return 0
        fi
    done
}

# Display table of data
# Usage: print_table "Header1|Header2" "Row1Col1|Row1Col2" "Row2Col1|Row2Col2"
print_table() {
    local -a rows=("$@")
    
    # Calculate column widths
    local -a widths=()
    local max_cols=0
    
    for row in "${rows[@]}"; do
        IFS='|' read -ra cols <<< "$row"
        [[ ${#cols[@]} -gt $max_cols ]] && max_cols=${#cols[@]}
        
        for i in "${!cols[@]}"; do
            local len=${#cols[$i]}
            [[ -z "${widths[$i]}" || $len -gt ${widths[$i]} ]] && widths[$i]=$len
        done
    done
    
    # Print table
    for row_idx in "${!rows[@]}"; do
        IFS='|' read -ra cols <<< "${rows[$row_idx]}"
        
        for i in "${!cols[@]}"; do
            printf "%-$((widths[i] + 2))s" "${cols[$i]}"
        done
        echo ""
        
        # Print separator after header
        if [[ $row_idx -eq 0 ]]; then
            for width in "${widths[@]}"; do
                printf '%*s' "$((width + 2))" '' | tr ' ' '─'
            done
            echo ""
        fi
    done
}