#!/usr/bin/env bash
#
# Git Sync Utility - Main Sync Script
# Orchestrates the interactive sync process across multiple repositories
#
set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly INSTALL_DIR="${HOME}/.git-sync-utils"
readonly CONFIG_FILE="${INSTALL_DIR}/config.json"
readonly LOG_FILE="${INSTALL_DIR}/sync.log"

# Source library files
source "${INSTALL_DIR}/lib/ui.sh" 2>/dev/null || {
    echo "ERROR: Library files not found. Run install.sh first." >&2
    exit 1
}
source "${INSTALL_DIR}/lib/config.sh"
source "${INSTALL_DIR}/lib/git-ops.sh"

# Global state tracking
declare -i REPOS_SYNCED=0
declare -i REPOS_SKIPPED=0
declare -i REPOS_ERRORED=0

# Signal handling - ensure clean exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script interrupted (exit code: ${exit_code})"
    fi
    print_summary
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

# Logging function with timestamp
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

# Print usage information
print_usage() {
    cat <<EOF
Usage: git-sync [OPTIONS]

Interactive Git sync utility for end-of-day branch backups.

Options:
    -d, --dry-run       Preview what would be synced without executing
    -h, --help          Show this help message
    -v, --version       Show version information
    --config            Show current configuration
    --status            Show repositories with uncommitted changes

Examples:
    git-sync            # Run interactive sync
    git-sync --dry-run  # Preview sync without executing
    git-sync --status   # Check which repos need syncing

Configuration: ${CONFIG_FILE}
Logs: ${LOG_FILE}
EOF
}

# Parse command line arguments
parse_args() {
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--version)
                echo "git-sync version ${SCRIPT_VERSION}"
                exit 0
                ;;
            --config)
                print_config
                exit 0
                ;;
            --status)
                show_repo_status
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

# Discover Git repositories matching criteria
discover_repositories() {
    local projects_root
    local max_depth
    local branch_prefix
    
    projects_root=$(get_config_value "projectsRoot")
    max_depth=$(get_config_value "maxDepth")
    branch_prefix=$(get_config_value "branchPrefix" | sed 's/\*/.*/')
    
    log_info "Scanning for repositories in ${projects_root}..."
    log_to_file "Starting repository discovery"
    
    local -a repos=()
    
    # Find all .git directories within max depth
    while IFS= read -r -d '' git_dir; do
        local repo_dir
        repo_dir=$(dirname "$git_dir")
        
        # Check if repo should be excluded
        if is_repo_excluded "$repo_dir"; then
            log_debug "Skipping excluded repo: ${repo_dir}"
            continue
        fi
        
        # Check if current branch matches prefix
        cd "$repo_dir" || continue
        local current_branch
        current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
        
        if [[ -z "$current_branch" ]]; then
            log_debug "Skipping ${repo_dir} (detached HEAD)"
            continue
        fi
        
        if [[ ! "$current_branch" =~ ^${branch_prefix%/} ]]; then
            log_debug "Skipping ${repo_dir} (branch '${current_branch}' doesn't match prefix)"
            continue
        fi
        
        # Check if there are uncommitted changes or unpushed commits
        if has_uncommitted_changes || has_unpushed_commits; then
            repos+=("$repo_dir")
        fi
        
    done < <(find "${projects_root}" -maxdepth "$max_depth" -type d -name ".git" -print0 2>/dev/null)
    
    echo "${repos[@]}"
}

# Show current status of repositories
show_repo_status() {
    local repos
    IFS=' ' read -r -a repos <<< "$(discover_repositories)"
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        print_success "No repositories with uncommitted changes found."
        return 0
    fi
    
    print_header "Repository Status"
    echo ""
    
    for repo_dir in "${repos[@]}"; do
        cd "$repo_dir" || continue
        
        local repo_name
        repo_name=$(basename "$repo_dir")
        local current_branch
        current_branch=$(git symbolic-ref --short HEAD)
        
        echo -e "${BLUE}📦 ${repo_name}${NC} (branch: ${YELLOW}${current_branch}${NC})"
        
        # Show uncommitted changes
        local modified
        modified=$(git diff --name-only | wc -l)
        local untracked
        untracked=$(git ls-files --others --exclude-standard | wc -l)
        local staged
        staged=$(git diff --cached --name-only | wc -l)
        
        [[ $staged -gt 0 ]] && echo "  • ${staged} staged files"
        [[ $modified -gt 0 ]] && echo "  • ${modified} modified files"
        [[ $untracked -gt 0 ]] && echo "  • ${untracked} untracked files"
        
        # Show unpushed commits
        local unpushed
        unpushed=$(git log @{u}.. --oneline 2>/dev/null | wc -l || echo 0)
        [[ $unpushed -gt 0 ]] && echo "  • ${unpushed} unpushed commits"
        
        echo ""
    done
}

# Process a single repository
process_repository() {
    local repo_dir="$1"
    local repo_name
    repo_name=$(basename "$repo_dir")
    
    cd "$repo_dir" || {
        log_error "Cannot access ${repo_dir}"
        ((REPOS_ERRORED++))
        return 1
    }
    
    local current_branch
    current_branch=$(git symbolic-ref --short HEAD)
    
    log_to_file "Processing repository: ${repo_dir} (${current_branch})"
    
    print_repo_header "$repo_name" "$current_branch"
    
    # Show current status
    show_git_status
    
    # Interactive staging prompt
    echo ""
    local action
    action=$(prompt_action "What would you like to do?" \
        "a:Add all and commit" \
        "i:Interactive staging" \
        "s:Skip this repository" \
        "q:Quit sync")
    
    case "$action" in
        a)
            process_add_all "$repo_dir" "$current_branch"
            ;;
        i)
            process_interactive "$repo_dir" "$current_branch"
            ;;
        s)
            log_info "Skipping ${repo_name}"
            log_to_file "Skipped: ${repo_dir}"
            ((REPOS_SKIPPED++))
            return 0
            ;;
        q)
            log_info "Sync cancelled by user"
            exit 0
            ;;
        *)
            log_warn "Invalid choice, skipping repository"
            ((REPOS_SKIPPED++))
            return 0
            ;;
    esac
}

# Process "add all" workflow
process_add_all() {
    local repo_dir="$1"
    local branch="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would stage all changes"
        return 0
    fi
    
    # Stage all changes
    git add -A || {
        log_error "Failed to stage changes"
        ((REPOS_ERRORED++))
        return 1
    }
    
    # Get commit message
    local commit_msg
    commit_msg=$(prompt_input "Commit message" "WIP: End of day sync $(date +%Y-%m-%d)")
    
    # Commit
    if ! git commit -m "$commit_msg"; then
        log_error "Failed to commit changes"
        ((REPOS_ERRORED++))
        return 1
    fi
    
    # Push
    if ! safe_git_push "$branch"; then
        log_error "Failed to push changes"
        ((REPOS_ERRORED++))
        return 1
    fi
    
    log_success "Successfully synced ${repo_dir##*/}"
    log_to_file "Synced: ${repo_dir} (add all)"
    ((REPOS_SYNCED++))
}

# Process interactive staging workflow
process_interactive() {
    local repo_dir="$1"
    local branch="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run interactive staging"
        return 0
    fi
    
    # Run git add -p for interactive staging
    log_info "Starting interactive staging (use 'y' to stage, 'n' to skip, 'q' to quit)..."
    
    if ! git add -p; then
        log_warn "Interactive staging cancelled or no changes selected"
        ((REPOS_SKIPPED++))
        return 0
    fi
    
    # Check if anything was staged
    if ! git diff --cached --quiet 2>/dev/null; then
        # Get commit message
        local commit_msg
        commit_msg=$(prompt_input "Commit message" "WIP: Partial sync $(date +%Y-%m-%d)")
        
        # Commit staged changes
        if ! git commit -m "$commit_msg"; then
            log_error "Failed to commit changes"
            ((REPOS_ERRORED++))
            return 1
        fi
        
        # Push
        if ! safe_git_push "$branch"; then
            log_error "Failed to push changes"
            ((REPOS_ERRORED++))
            return 1
        fi
        
        log_success "Successfully synced ${repo_dir##*/}"
        log_to_file "Synced: ${repo_dir} (interactive)"
        ((REPOS_SYNCED++))
        
        # Handle remaining unstaged changes
        if has_uncommitted_changes; then
            handle_remaining_changes
        fi
    else
        log_warn "No changes staged, skipping commit"
        ((REPOS_SKIPPED++))
    fi
}

# Handle remaining unstaged changes after partial commit
handle_remaining_changes() {
    echo ""
    log_info "You have remaining unstaged changes:"
    git status --short
    
    echo ""
    local stash_action
    stash_action=$(prompt_action "What to do with remaining changes?" \
        "stash:Stash with message" \
        "skip:Leave unstaged")
    
    if [[ "$stash_action" == "stash" ]]; then
        local stash_msg
        stash_msg=$(prompt_input "Stash message" "Unstaged changes $(date +%Y-%m-%d)")
        
        if git stash push -u -m "$stash_msg"; then
            log_success "Stashed remaining changes"
            log_to_file "Stashed remaining changes: ${stash_msg}"
        else
            log_error "Failed to stash changes"
        fi
    else
        log_info "Leaving changes unstaged"
    fi
}

# Print final summary
print_summary() {
    echo ""
    print_header "Sync Summary"
    echo ""
    
    echo -e "  ${GREEN}✅ Synced:${NC}  ${REPOS_SYNCED} repositories"
    echo -e "  ${YELLOW}⏭️  Skipped:${NC} ${REPOS_SKIPPED} repositories"
    echo -e "  ${RED}❌ Errors:${NC}  ${REPOS_ERRORED} repositories"
    echo ""
    
    if [[ $REPOS_SYNCED -gt 0 ]]; then
        log_success "Sync completed successfully!"
    elif [[ $REPOS_SKIPPED -gt 0 ]]; then
        log_info "All repositories were skipped"
    else
        log_warn "No repositories were synced"
    fi
    
    log_to_file "Summary: synced=${REPOS_SYNCED}, skipped=${REPOS_SKIPPED}, errors=${REPOS_ERRORED}"
}

# Main execution flow
main() {
    parse_args "$@"
    
    # Verify config exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration not found. Run install.sh first."
        exit 1
    fi
    
    print_banner
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Running in DRY RUN mode - no changes will be made"
        echo ""
    fi
    
    # Discover repositories
    local repos
    IFS=' ' read -r -a repos <<< "$(discover_repositories)"
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        print_success "No repositories with uncommitted changes found."
        log_to_file "No repositories found needing sync"
        exit 0
    fi
    
    log_info "Found ${#repos[@]} repository(ies) with uncommitted changes"
    echo ""
    
    # Confirm before proceeding
    if ! confirm_proceed "Process these repositories?"; then
        log_info "Sync cancelled by user"
        exit 0
    fi
    
    echo ""
    
    # Process each repository
    for repo_dir in "${repos[@]}"; do
        process_repository "$repo_dir"
        echo ""
        echo "$(print_separator)"
        echo ""
    done
}

main "$@"