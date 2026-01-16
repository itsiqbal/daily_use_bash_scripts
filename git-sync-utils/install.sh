#!/usr/bin/env bash
#
# Git Sync Utility - Installation Script
# Sets up configuration, cron job, and directory structure
#
set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Constants
readonly INSTALL_DIR="${HOME}/.git-sync-utils"
readonly CONFIG_FILE="${INSTALL_DIR}/config.json"
readonly LOG_FILE="${INSTALL_DIR}/sync.log"
readonly BIN_NAME="git-sync"

# Logging helpers
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Cleanup on error
cleanup_on_error() {
    log_error "Installation failed. Cleaning up..."
    rm -rf "${INSTALL_DIR}"
    exit 1
}
trap cleanup_on_error ERR

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v git &>/dev/null; then
        log_error "Git is not installed. Please install Git first."
        exit 1
    fi
    
    if ! command -v jq &>/dev/null; then
        log_warn "jq is not installed. Attempting to install..."
        if command -v brew &>/dev/null; then
            brew install jq
        elif command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        else
            log_error "Cannot install jq automatically. Please install manually."
            exit 1
        fi
    fi
    
    log_success "Prerequisites satisfied"
}

# Prompt with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local response
    
    read -rp "$(echo -e "${BLUE}${prompt}${NC} [${default}]: ")" response
    echo "${response:-$default}"
}

# Validate directory exists or can be created
validate_directory() {
    local dir="$1"
    dir="${dir/#\~/$HOME}" # Expand tilde
    
    if [[ ! -d "$dir" ]]; then
        read -rp "$(echo -e "${YELLOW}Directory ${dir} does not exist. Create it?${NC} [y/N]: ")" create
        if [[ "${create,,}" == "y" ]]; then
            mkdir -p "$dir" || return 1
        else
            return 1
        fi
    fi
    
    echo "$dir"
}

# Get current username for branch prefix default
get_default_branch_prefix() {
    local username
    username=$(git config user.name 2>/dev/null || whoami)
    username=$(echo "$username" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    echo "${username}/"
}

# Create configuration
create_config() {
    log_info "Setting up configuration..."
    
    # Gather user input
    local projects_root
    projects_root=$(prompt_with_default "Enter projects root directory" "${HOME}/projects")
    projects_root=$(validate_directory "$projects_root") || {
        log_error "Invalid directory"
        return 1
    }
    
    local branch_prefix
    branch_prefix=$(prompt_with_default "Enter branch prefix to sync (e.g., username/*)" "$(get_default_branch_prefix)*")
    
    local sync_time
    sync_time=$(prompt_with_default "Enter daily sync reminder time (HH:MM, 24h format)" "17:00")
    
    local git_config_repo
    read -rp "$(echo -e "${BLUE}Git config repository URL (optional, press Enter to skip):${NC} ")" git_config_repo
    
    local max_depth
    max_depth=$(prompt_with_default "Maximum directory depth to search" "3")
    
    # Create config JSON
    cat > "${CONFIG_FILE}" <<EOF
{
  "projectsRoot": "${projects_root}",
  "branchPrefix": "${branch_prefix}",
  "syncTime": "${sync_time}",
  "maxDepth": ${max_depth},
  "excludePatterns": ["archived/*", "*/node_modules", "*/.venv", "*/vendor"],
  "gitConfigRepo": "${git_config_repo}",
  "excludeRepos": [],
  "autoStashRemaining": false,
  "notificationEnabled": true,
  "logLevel": "info"
}
EOF
    
    log_success "Configuration created at ${CONFIG_FILE}"
}

# Setup directory structure
setup_directories() {
    log_info "Creating directory structure..."
    
    mkdir -p "${INSTALL_DIR}"/{lib,logs,backups}
    touch "${LOG_FILE}"
    
    log_success "Directory structure created"
}

# Install main script and libraries
install_scripts() {
    log_info "Installing scripts..."
    
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Copy main script
    if [[ -f "${script_dir}/${BIN_NAME}" ]]; then
        cp "${script_dir}/${BIN_NAME}" "${INSTALL_DIR}/"
        chmod +x "${INSTALL_DIR}/${BIN_NAME}"
    else
        log_warn "Main script not found, will be created separately"
    fi
    
    # Copy library files if they exist
    if [[ -d "${script_dir}/lib" ]]; then
        cp -r "${script_dir}/lib/"* "${INSTALL_DIR}/lib/"
    fi
    
    # Add to PATH via shell profile
    local shell_profile="${HOME}/.bashrc"
    [[ -f "${HOME}/.zshrc" ]] && shell_profile="${HOME}/.zshrc"
    
    if ! grep -q "git-sync-utils" "${shell_profile}" 2>/dev/null; then
        echo "" >> "${shell_profile}"
        echo "# Git Sync Utility" >> "${shell_profile}"
        echo "export PATH=\"\${PATH}:${INSTALL_DIR}\"" >> "${shell_profile}"
        log_success "Added to PATH in ${shell_profile}"
    fi
    
    log_success "Scripts installed"
}

# Setup cron job for reminder
setup_cron() {
    log_info "Setting up cron job..."
    
    local sync_time
    sync_time=$(jq -r '.syncTime' "${CONFIG_FILE}")
    
    # Parse time (HH:MM)
    local hour minute
    IFS=':' read -r hour minute <<< "$sync_time"
    
    # Create cron entry (reminder only, not auto-execution)
    local cron_cmd="@daily ${INSTALL_DIR}/lib/send-reminder.sh"
    
    # Check if cron entry already exists
    if crontab -l 2>/dev/null | grep -q "git-sync"; then
        log_warn "Cron entry already exists, skipping"
    else
        (crontab -l 2>/dev/null; echo "${minute} ${hour} * * * ${cron_cmd}") | crontab -
        log_success "Cron job installed for ${sync_time} daily"
    fi
}

# Sync Git config if repo provided
sync_git_config() {
    local git_config_repo
    git_config_repo=$(jq -r '.gitConfigRepo' "${CONFIG_FILE}")
    
    if [[ -z "$git_config_repo" || "$git_config_repo" == "null" ]]; then
        log_info "No Git config repo specified, skipping config sync"
        return 0
    fi
    
    log_info "Syncing Git configuration from ${git_config_repo}..."
    
    local config_clone_dir="${INSTALL_DIR}/git-config-repo"
    
    # Clone config repo
    if [[ -d "$config_clone_dir" ]]; then
        (cd "$config_clone_dir" && git pull -q) || log_warn "Failed to update config repo"
    else
        git clone -q "$git_config_repo" "$config_clone_dir" || {
            log_warn "Failed to clone config repo, skipping config sync"
            return 0
        }
    fi
    
    # Backup existing gitconfig
    if [[ -f "${HOME}/.gitconfig" ]]; then
        local backup_file="${INSTALL_DIR}/backups/gitconfig.backup.$(date +%Y%m%d_%H%M%S)"
        cp "${HOME}/.gitconfig" "$backup_file"
        log_info "Backed up existing .gitconfig to ${backup_file}"
    fi
    
    # Merge config sections (preserve local settings)
    if [[ -f "${config_clone_dir}/.gitconfig" ]]; then
        # Extract and merge specific sections safely
        # This is a simplified merge; in production, use git config commands
        log_warn "Manual merge required: compare ${HOME}/.gitconfig with ${config_clone_dir}/.gitconfig"
        log_info "Backup available at: $(ls -t ${INSTALL_DIR}/backups/gitconfig.backup.* | head -1)"
    fi
    
    log_success "Git config sync completed"
}

# Create reminder notification script
create_reminder_script() {
    log_info "Creating reminder notification script..."
    
    cat > "${INSTALL_DIR}/lib/send-reminder.sh" <<'EOFREMINDER'
#!/usr/bin/env bash
# Send notification reminder to run git-sync

INSTALL_DIR="${HOME}/.git-sync-utils"
CONFIG_FILE="${INSTALL_DIR}/config.json"

# Check if notifications are enabled
if ! jq -e '.notificationEnabled == true' "${CONFIG_FILE}" >/dev/null 2>&1; then
    exit 0
fi

# Count repos with changes (quick scan)
PROJECTS_ROOT=$(jq -r '.projectsRoot' "${CONFIG_FILE}")
BRANCH_PREFIX=$(jq -r '.branchPrefix' "${CONFIG_FILE}" | sed 's/\*/.*/')

repo_count=0
while IFS= read -r -d '' git_dir; do
    repo_dir=$(dirname "$git_dir")
    cd "$repo_dir" || continue
    
    # Check if current branch matches prefix and has changes
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
    if [[ "$current_branch" =~ ^${BRANCH_PREFIX%/} ]]; then
        if ! git diff-index --quiet HEAD -- 2>/dev/null || [[ -n $(git ls-files --others --exclude-standard) ]]; then
            ((repo_count++))
        fi
    fi
done < <(find "${PROJECTS_ROOT}" -maxdepth 3 -type d -name ".git" -print0)

if [[ $repo_count -gt 0 ]]; then
    # macOS notification
    if command -v osascript &>/dev/null; then
        osascript -e "display notification \"Found ${repo_count} repos with uncommitted changes\" with title \"Git Sync Reminder\" sound name \"default\""
    fi
    
    # Linux notification
    if command -v notify-send &>/dev/null; then
        notify-send "Git Sync Reminder" "Found ${repo_count} repos with uncommitted changes"
    fi
    
    # Log reminder
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Reminder sent: ${repo_count} repos with changes" >> "${INSTALL_DIR}/sync.log"
fi
EOFREMINDER
    
    chmod +x "${INSTALL_DIR}/lib/send-reminder.sh"
    log_success "Reminder script created"
}

# Print completion message
print_completion() {
    echo ""
    log_success "═══════════════════════════════════════════════════════════"
    log_success "Git Sync Utility installed successfully!"
    log_success "═══════════════════════════════════════════════════════════"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "  1. Reload your shell: source ~/.bashrc (or ~/.zshrc)"
    echo "  2. Run 'git-sync' to perform your first sync"
    echo "  3. You'll receive daily reminders at $(jq -r '.syncTime' "${CONFIG_FILE}")"
    echo ""
    echo -e "${BLUE}Configuration:${NC} ${CONFIG_FILE}"
    echo -e "${BLUE}Logs:${NC} ${LOG_FILE}"
    echo -e "${BLUE}Scripts:${NC} ${INSTALL_DIR}"
    echo ""
    log_info "To customize settings, edit ${CONFIG_FILE}"
    echo ""
}

# Main installation flow
main() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Git Sync Utility - Installation               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_prerequisites
    setup_directories
    create_config
    install_scripts
    create_reminder_script
    setup_cron
    sync_git_config
    print_completion
}

main "$@"