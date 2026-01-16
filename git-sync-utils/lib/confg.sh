#!/usr/bin/env bash
#
# Git Sync Utility - Configuration Library
# Functions for reading and managing configuration
#

readonly CONFIG_FILE="${INSTALL_DIR:-${HOME}/.git-sync-utils}/config.json"

# Ensure jq is available
check_jq() {
    if ! command -v jq &>/dev/null; then
        log_error "jq is required but not installed. Please install jq first."
        exit 1
    fi
}

# Get configuration value by key
# Usage: get_config_value "projectsRoot"
get_config_value() {
    local key="$1"
    local default="${2:-}"
    
    check_jq
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        return 1
    fi
    
    local value
    value=$(jq -r ".${key} // empty" "$CONFIG_FILE" 2>/dev/null)
    
    if [[ -z "$value" || "$value" == "null" ]]; then
        if [[ -n "$default" ]]; then
            echo "$default"
        else
            log_error "Configuration key '${key}' not found and no default provided"
            return 1
        fi
    else
        # Expand tilde in paths
        value="${value/#\~/$HOME}"
        echo "$value"
    fi
}

# Set configuration value
# Usage: set_config_value "key" "value"
set_config_value() {
    local key="$1"
    local value="$2"
    
    check_jq
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        return 1
    fi
    
    # Create backup before modification
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # Update config using jq
    local tmp_file
    tmp_file=$(mktemp)
    
    if jq --arg key "$key" --arg val "$value" '.[$key] = $val' "$CONFIG_FILE" > "$tmp_file"; then
        mv "$tmp_file" "$CONFIG_FILE"
        log_success "Updated configuration: ${key} = ${value}"
        return 0
    else
        log_error "Failed to update configuration"
        rm -f "$tmp_file"
        mv "${CONFIG_FILE}.bak" "$CONFIG_FILE"
        return 1
    fi
}

# Get array configuration value
# Usage: get_config_array "excludePatterns"
get_config_array() {
    local key="$1"
    
    check_jq
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        return 1
    fi
    
    jq -r ".${key}[]?" "$CONFIG_FILE" 2>/dev/null
}

# Check if repository should be excluded
# Usage: is_repo_excluded "/path/to/repo"
is_repo_excluded() {
    local repo_path="$1"
    
    # Get exclude patterns
    local -a exclude_patterns
    while IFS= read -r pattern; do
        exclude_patterns+=("$pattern")
    done < <(get_config_array "excludePatterns")
    
    # Get explicitly excluded repos
    local -a exclude_repos
    while IFS= read -r excluded_repo; do
        exclude_repos+=("$excluded_repo")
    done < <(get_config_array "excludeRepos")
    
    # Check if repo is explicitly excluded
    for excluded in "${exclude_repos[@]}"; do
        excluded="${excluded/#\~/$HOME}"
        if [[ "$repo_path" == "$excluded" ]]; then
            return 0  # Is excluded
        fi
    done
    
    # Check if repo matches any exclude pattern
    for pattern in "${exclude_patterns[@]}"; do
        # Convert glob pattern to regex-like match
        if [[ "$repo_path" == *"$pattern"* ]] || [[ "$repo_path" =~ $pattern ]]; then
            return 0  # Is excluded
        fi
    done
    
    return 1  # Not excluded
}

# Validate configuration file
validate_config() {
    check_jq
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        return 1
    fi
    
    # Check JSON syntax
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        log_error "Invalid JSON in configuration file"
        return 1
    fi
    
    # Validate required fields
    local -a required_fields=("projectsRoot" "branchPrefix" "maxDepth")
    local valid=true
    
    for field in "${required_fields[@]}"; do
        if ! jq -e ".${field}" "$CONFIG_FILE" >/dev/null 2>&1; then
            log_error "Required configuration field missing: ${field}"
            valid=false
        fi
    done
    
    # Validate projects root exists
    local projects_root
    projects_root=$(get_config_value "projectsRoot")
    projects_root="${projects_root/#\~/$HOME}"
    
    if [[ ! -d "$projects_root" ]]; then
        log_error "Projects root directory does not exist: ${projects_root}"
        valid=false
    fi
    
    # Validate max depth is a positive integer
    local max_depth
    max_depth=$(get_config_value "maxDepth")
    
    if ! [[ "$max_depth" =~ ^[0-9]+$ ]] || [[ "$max_depth" -lt 1 ]]; then
        log_error "maxDepth must be a positive integer, got: ${max_depth}"
        valid=false
    fi
    
    [[ "$valid" == "true" ]] && return 0 || return 1
}

# Print current configuration
print_config() {
    check_jq
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        return 1
    fi
    
    print_header "Current Configuration"
    echo ""
    
    # Pretty print with colors
    echo -e "${CYAN}Location:${NC} ${CONFIG_FILE}"
    echo ""
    
    # Key-value pairs
    local projects_root branch_prefix sync_time max_depth
    projects_root=$(get_config_value "projectsRoot")
    branch_prefix=$(get_config_value "branchPrefix")
    sync_time=$(get_config_value "syncTime")
    max_depth=$(get_config_value "maxDepth")
    
    echo -e "${BOLD}General Settings:${NC}"
    echo -e "  Projects Root:  ${GREEN}${projects_root}${NC}"
    echo -e "  Branch Prefix:  ${GREEN}${branch_prefix}${NC}"
    echo -e "  Sync Time:      ${GREEN}${sync_time}${NC}"
    echo -e "  Max Depth:      ${GREEN}${max_depth}${NC}"
    echo ""
    
    # Exclude patterns
    echo -e "${BOLD}Exclude Patterns:${NC}"
    if ! get_config_array "excludePatterns" | grep -q .; then
        echo "  (none)"
    else
        while IFS= read -r pattern; do
            echo -e "  ${YELLOW}•${NC} ${pattern}"
        done < <(get_config_array "excludePatterns")
    fi
    echo ""
    
    # Excluded repos
    echo -e "${BOLD}Excluded Repositories:${NC}"
    if ! get_config_array "excludeRepos" | grep -q .; then
        echo "  (none)"
    else
        while IFS= read -r repo; do
            echo -e "  ${YELLOW}•${NC} ${repo}"
        done < <(get_config_array "excludeRepos")
    fi
    echo ""
    
    # Git config repo
    local git_config_repo
    git_config_repo=$(get_config_value "gitConfigRepo" "")
    if [[ -n "$git_config_repo" && "$git_config_repo" != "null" ]]; then
        echo -e "${BOLD}Git Config Repository:${NC}"
        echo -e "  ${GREEN}${git_config_repo}${NC}"
        echo ""
    fi
    
    # Feature flags
    echo -e "${BOLD}Features:${NC}"
    echo -e "  Auto-stash remaining:  $(get_config_value 'autoStashRemaining' 'false')"
    echo -e "  Notifications:         $(get_config_value 'notificationEnabled' 'true')"
    echo ""
}

# Add repository to exclude list
# Usage: add_excluded_repo "/path/to/repo"
add_excluded_repo() {
    local repo_path="$1"
    
    check_jq
    
    # Normalize path
    repo_path="${repo_path/#\~/$HOME}"
    
    # Check if already excluded
    if is_repo_excluded "$repo_path"; then
        log_warn "Repository already excluded: ${repo_path}"
        return 0
    fi
    
    # Create backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # Add to excludeRepos array
    local tmp_file
    tmp_file=$(mktemp)
    
    if jq --arg repo "$repo_path" '.excludeRepos += [$repo] | .excludeRepos |= unique' "$CONFIG_FILE" > "$tmp_file"; then
        mv "$tmp_file" "$CONFIG_FILE"
        log_success "Added repository to exclude list: ${repo_path}"
        return 0
    else
        log_error "Failed to update exclude list"
        rm -f "$tmp_file"
        mv "${CONFIG_FILE}.bak" "$CONFIG_FILE"
        return 1
    fi
}

# Remove repository from exclude list
# Usage: remove_excluded_repo "/path/to/repo"
remove_excluded_repo() {
    local repo_path="$1"
    
    check_jq
    
    # Normalize path
    repo_path="${repo_path/#\~/$HOME}"
    
    # Create backup
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    
    # Remove from excludeRepos array
    local tmp_file
    tmp_file=$(mktemp)
    
    if jq --arg repo "$repo_path" '.excludeRepos -= [$repo]' "$CONFIG_FILE" > "$tmp_file"; then
        mv "$tmp_file" "$CONFIG_FILE"
        log_success "Removed repository from exclude list: ${repo_path}"
        return 0
    else
        log_error "Failed to update exclude list"
        rm -f "$tmp_file"
        mv "${CONFIG_FILE}.bak" "$CONFIG_FILE"
        return 1
    fi
}

# Get configuration schema (for validation or display)
get_config_schema() {
    cat <<'EOF'
{
  "projectsRoot": "string (path)",
  "branchPrefix": "string (pattern with optional *)",
  "syncTime": "string (HH:MM format)",
  "maxDepth": "integer (1-10)",
  "excludePatterns": "array of strings (glob patterns)",
  "gitConfigRepo": "string (git URL, optional)",
  "excludeRepos": "array of strings (paths)",
  "autoStashRemaining": "boolean",
  "notificationEnabled": "boolean",
  "logLevel": "string (debug|info|warn|error)"
}
EOF
}

# Export config value to environment
# Usage: export_config_to_env "projectsRoot" "GIT_SYNC_ROOT"
export_config_to_env() {
    local config_key="$1"
    local env_var="$2"
    
    local value
    value=$(get_config_value "$config_key")
    
    if [[ -n "$value" ]]; then
        export "${env_var}=${value}"
        return 0
    else
        return 1
    fi
}