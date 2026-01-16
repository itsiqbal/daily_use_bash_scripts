#!/usr/bin/env bash
#
# Git Sync Utility - Git Operations Library
# Safe, defensive Git wrapper functions
#

# Check if directory is a Git repository
is_git_repo() {
    local dir="${1:-.}"
    git -C "$dir" rev-parse --git-dir &>/dev/null
}

# Get current branch name
# Returns empty string if in detached HEAD state
get_current_branch() {
    git symbolic-ref --short HEAD 2>/dev/null || echo ""
}

# Get remote tracking branch for current branch
# Returns empty string if no tracking branch
get_tracking_branch() {
    git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo ""
}

# Check if repository has uncommitted changes
has_uncommitted_changes() {
    # Check for staged, unstaged, or untracked files
    ! git diff-index --quiet HEAD -- 2>/dev/null || \
    [[ -n $(git ls-files --others --exclude-standard 2>/dev/null) ]]
}

# Check if repository has unpushed commits
has_unpushed_commits() {
    local tracking_branch
    tracking_branch=$(get_tracking_branch)
    
    # If no tracking branch, assume no unpushed commits
    [[ -z "$tracking_branch" ]] && return 1
    
    # Compare local vs remote
    local local_commit remote_commit
    local_commit=$(git rev-parse HEAD 2>/dev/null)
    remote_commit=$(git rev-parse "$tracking_branch" 2>/dev/null)
    
    [[ "$local_commit" != "$remote_commit" ]]
}

# Check if remote branch exists
remote_branch_exists() {
    local branch="$1"
    local remote="${2:-origin}"
    
    git ls-remote --heads "$remote" "$branch" 2>/dev/null | grep -q "$branch"
}

# Check if remote has diverged from local
has_remote_diverged() {
    local tracking_branch
    tracking_branch=$(get_tracking_branch)
    
    [[ -z "$tracking_branch" ]] && return 1
    
    # Fetch latest remote refs (quietly)
    git fetch --quiet 2>/dev/null || return 2
    
    # Check for divergence
    local ahead behind
    ahead=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
    behind=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    
    # Diverged if remote has commits we don't have
    [[ $ahead -gt 0 ]]
}

# Safe Git push with conflict detection
# Returns: 0 on success, 1 on failure, 2 on conflict
safe_git_push() {
    local branch="${1:-$(get_current_branch)}"
    local remote="${2:-origin}"
    local force="${3:-false}"
    
    if [[ -z "$branch" ]]; then
        log_error "Cannot push: not on a branch (detached HEAD?)"
        return 1
    fi
    
    # Check if tracking branch exists
    local tracking_branch
    tracking_branch=$(get_tracking_branch)
    
    if [[ -z "$tracking_branch" ]]; then
        # No tracking branch, set upstream on push
        log_info "Setting upstream branch: ${remote}/${branch}"
        
        if git push --set-upstream "$remote" "$branch" 2>&1 | tee /tmp/git-push.log; then
            log_success "Pushed to ${remote}/${branch} (new upstream)"
            return 0
        else
            log_error "Failed to push to ${remote}/${branch}"
            cat /tmp/git-push.log >&2
            return 1
        fi
    fi
    
    # Check for remote divergence
    if has_remote_diverged; then
        log_error "Remote branch has diverged. Cannot push safely."
        log_warn "Fetch latest changes and resolve conflicts manually."
        log_warn "Remote: ${tracking_branch}"
        
        # Show divergence info
        local ahead behind
        ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
        behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
        
        echo ""
        log_info "Your branch is ahead by ${ahead} commit(s)"
        log_info "Remote branch is ahead by ${behind} commit(s)"
        echo ""
        
        return 2  # Conflict detected
    fi
    
    # Perform push
    log_info "Pushing to ${remote}/${branch}..."
    
    local push_args=("--porcelain")
    [[ "$force" == "true" ]] && push_args+=("--force-with-lease")
    
    if git push "${push_args[@]}" "$remote" "$branch" 2>&1 | tee /tmp/git-push.log; then
        log_success "✓ Pushed to ${remote}/${branch}"
        return 0
    else
        log_error "Push failed"
        
        # Check for common errors
        if grep -q "non-fast-forward" /tmp/git-push.log; then
            log_error "Remote has changes that are not in local branch"
            log_warn "Run 'git pull' to merge remote changes first"
            return 2
        elif grep -q "authentication failed" /tmp/git-push.log; then
            log_error "Authentication failed - check your Git credentials"
            return 1
        elif grep -q "Permission denied" /tmp/git-push.log; then
            log_error "Permission denied - check repository access"
            return 1
        fi
        
        cat /tmp/git-push.log >&2
        return 1
    fi
}

# Safely stash changes with message
safe_stash() {
    local message="${1:-Stashed changes $(date +%Y-%m-%d_%H:%M:%S)}"
    local include_untracked="${2:-true}"
    
    local stash_args=("push" "-m" "$message")
    [[ "$include_untracked" == "true" ]] && stash_args+=("-u")
    
    if git stash "${stash_args[@]}" 2>&1 | tee /tmp/git-stash.log; then
        log_success "Stashed changes: ${message}"
        return 0
    else
        log_error "Failed to stash changes"
        cat /tmp/git-stash.log >&2
        return 1
    fi
}

# Check if working directory is clean
is_working_tree_clean() {
    git diff-index --quiet HEAD -- 2>/dev/null && \
    [[ -z $(git ls-files --others --exclude-standard) ]]
}

# Get repository root directory
get_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# Get relative path within repository
get_repo_relative_path() {
    local file="$1"
    git ls-files --full-name "$file" 2>/dev/null || echo "$file"
}

# Count uncommitted changes by type
count_changes() {
    local staged modified untracked
    
    staged=$(git diff --cached --name-only 2>/dev/null | wc -l)
    modified=$(git diff --name-only 2>/dev/null | wc -l)
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)
    
    echo "staged:$staged modified:$modified untracked:$untracked"
}

# Check for large files before commit
# Returns: 0 if OK, 1 if large files found
check_large_files() {
    local size_limit_mb="${1:-10}"
    local size_limit_bytes=$((size_limit_mb * 1024 * 1024))
    
    local -a large_files=()
    
    # Check staged files
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        if [[ -f "$file" ]]; then
            local file_size
            file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
            
            if [[ $file_size -gt $size_limit_bytes ]]; then
                local size_mb=$((file_size / 1024 / 1024))
                large_files+=("${file} (${size_mb}MB)")
            fi
        fi
    done < <(git diff --cached --name-only 2>/dev/null)
    
    if [[ ${#large_files[@]} -gt 0 ]]; then
        log_warn "Found ${#large_files[@]} large file(s) staged for commit:"
        printf '  %s\n' "${large_files[@]}"
        echo ""
        
        if ! confirm_proceed "Commit these large files?"; then
            return 1
        fi
    fi
    
    return 0
}

# Scan for potential secrets in staged files
# Simple pattern matching - not comprehensive security
check_for_secrets() {
    local -a suspicious_patterns=(
        "password.*="
        "api[_-]?key.*="
        "secret.*="
        "token.*="
        "private[_-]?key"
        "BEGIN.*PRIVATE KEY"
    )
    
    local -a matches=()
    
    # Check staged files
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        for pattern in "${suspicious_patterns[@]}"; do
            if git diff --cached "$file" 2>/dev/null | grep -iE "$pattern" >/dev/null; then
                matches+=("${file}: potential secret (${pattern})")
            fi
        done
    done < <(git diff --cached --name-only 2>/dev/null)
    
    if [[ ${#matches[@]} -gt 0 ]]; then
        log_warn "⚠️  Potential secrets detected in staged files:"
        printf '  %s\n' "${matches[@]}"
        echo ""
        log_warn "Review changes carefully before committing!"
        echo ""
        
        if ! confirm_proceed "Continue with commit?"; then
            return 1
        fi
    fi
    
    return 0
}

# Get last commit info
get_last_commit_info() {
    local format="${1:-%h - %s (%cr) <%an>}"
    git log -1 --pretty="format:${format}" 2>/dev/null
}

# Check if branch is ahead of remote
is_ahead_of_remote() {
    local tracking_branch
    tracking_branch=$(get_tracking_branch)
    
    [[ -z "$tracking_branch" ]] && return 1
    
    local ahead
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    
    [[ $ahead -gt 0 ]]
}

# Check if branch is behind remote
is_behind_remote() {
    local tracking_branch
    tracking_branch=$(get_tracking_branch)
    
    [[ -z "$tracking_branch" ]] && return 1
    
    local behind
    behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
    
    [[ $behind -gt 0 ]]
}

# Get branch status summary
get_branch_status() {
    local branch
    branch=$(get_current_branch)
    
    if [[ -z "$branch" ]]; then
        echo "detached"
        return 1
    fi
    
    local tracking
    tracking=$(get_tracking_branch)
    
    if [[ -z "$tracking" ]]; then
        echo "no-upstream"
        return 0
    fi
    
    local ahead behind
    ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
    
    if [[ $ahead -eq 0 && $behind -eq 0 ]]; then
        echo "up-to-date"
    elif [[ $ahead -gt 0 && $behind -eq 0 ]]; then
        echo "ahead:${ahead}"
    elif [[ $ahead -eq 0 && $behind -gt 0 ]]; then
        echo "behind:${behind}"
    else
        echo "diverged:ahead=${ahead},behind=${behind}"
    fi
}

# Validate branch name
is_valid_branch_name() {
    local branch="$1"
    
    # Git branch name rules
    [[ -n "$branch" ]] && \
    [[ ! "$branch" =~ ^- ]] && \
    [[ ! "$branch" =~ \.\. ]] && \
    [[ ! "$branch" =~ [[:space:]] ]] && \
    [[ ! "$branch" =~ [\^~:\?*\[] ]] && \
    [[ ! "$branch" =~ /$ ]] && \
    [[ ! "$branch" =~ \.lock$ ]] && \
    [[ ! "$branch" =~ ^/ ]]
}