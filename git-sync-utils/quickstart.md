# Git Sync Utility - Quickstart Guide

## 60-Second Setup

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/git-sync-utils.git
cd git-sync-utils

# 2. Run installer
./install.sh

# 3. Follow prompts (all have sensible defaults)
# Press Enter to accept defaults or customize:
# - Projects directory: ~/projects
# - Branch prefix: your-username/*
# - Sync time: 17:00
# - Max depth: 3

# 4. Reload shell
source ~/.bashrc  # or ~/.zshrc

# 5. Test it!
git-sync --status
```

---

## Project Structure

```
git-sync-utils/
│
├── README.md                 # Full documentation
├── QUICKSTART.md            # This file
├── LICENSE                  # MIT License
│
├── install.sh               # One-time installation script
├── git-sync                 # Main executable (interactive sync)
│
├── lib/                     # Library modules
│   ├── ui.sh               # UI functions (colors, prompts, formatting)
│   ├── config.sh           # Configuration management (read/write config)
│   ├── git-ops.sh          # Git operations (safe wrappers for git commands)
│   └── send-reminder.sh    # Cron job script (sends notifications)
│
├── examples/                # Example configurations
│   ├── config.minimal.json
│   └── config.advanced.json
│
└── tests/                   # Test scripts (future)
    └── test-runner.sh
```

---

## First-Time Usage

### Step 1: Verify Installation

```bash
# Check version
git-sync --version

# View configuration
git-sync --config

# Check what would be synced
git-sync --status
```

### Step 2: Make Some Changes

```bash
# Go to a project matching your branch prefix
cd ~/projects/my-app

# Create/checkout a branch matching your prefix
git checkout -b your-username/test-sync

# Make some changes
echo "test" >> README.md

# Check status
git-sync --status
# Should show: my-app with uncommitted changes
```

### Step 3: Run Your First Sync

```bash
git-sync
```

You'll see:

```
╔═══════════════════════════════════════════════════════╗
║              Git Sync Utility v1.0                    ║
║          End-of-Day Repository Backup Tool            ║
╚═══════════════════════════════════════════════════════╝

[INFO] Scanning for repositories in /Users/you/projects...
[INFO] Found 1 repository(ies) with uncommitted changes

Process these repositories? [y/N]: y

📦 my-app (branch: your-username/test-sync)

Modified files (1):
  README.md

[a] Add all and commit  [i] Interactive staging  [s] Skip repo  [q] Quit
> a

Commit message [WIP: End of day sync 2026-01-16]: First sync test

[INFO] Pushing to origin/your-username/test-sync...
[SUCCESS] ✓ Pushed to origin/your-username/test-sync
[SUCCESS] Successfully synced my-app

───────────────────────────────────────────────────────────

Sync Summary
═══════════════════════════════════════════════════════════

  ✅ Synced:  1 repositories
  ⏭️  Skipped: 0 repositories
  ❌ Errors:  0 repositories

[SUCCESS] Sync completed successfully!
```

---

## Daily Workflow

### At EOD (5pm or your configured time)

1. **Notification appears**: "Git Sync: Found 3 repos with changes"

2. **Open terminal and run**:

   ```bash
   git-sync
   ```

3. **For each repository, choose**:

   - `a` = Add all changes, commit, and push (fastest)
   - `i` = Interactive staging for granular control
   - `s` = Skip this repository today
   - `q` = Exit sync process

4. **Review summary** at the end

### Next Morning

All your WIP branches are safely backed up to remote. If your laptop dies, you lose nothing!

---

## Common Scenarios

### Scenario 1: Granular Control (Some files ready, some not)

```bash
git-sync

# When prompted for a repo:
> i  # Choose interactive

# Git will ask about each change:
# y = stage this change
# n = skip this change
# q = stop staging

# Only staged changes are committed and pushed
# Remaining changes can be stashed or left uncommitted
```

### Scenario 2: Working on Multiple Features

```bash
# Morning: working on feature A
git checkout -b username/feature-a
# ... make changes ...

# Afternoon: context switch to feature B
git checkout -b username/feature-b
# ... make changes ...

# EOD: Both branches have uncommitted changes
git-sync
# Both will be discovered and you can sync them independently
```

### Scenario 3: Skip a Messy Repo

```bash
git-sync

📦 messy-experiment (branch: username/testing)
Modified files (47):
  ...

> s  # Skip this one, I'll clean it up later
```

### Scenario 4: Large Files Warning

```bash
git-sync
> a  # Add all

[WARN] Found 2 large file(s) staged for commit:
  video/demo.mp4 (250MB)
  data/export.csv (50MB)

Commit these large files? [y/N]: n

# Add to .gitignore instead
echo "video/*.mp4" >> .gitignore
```

---

## Configuration Examples

### Minimal Configuration

Perfect for getting started:

```json
{
  "projectsRoot": "~/projects",
  "branchPrefix": "john/*",
  "syncTime": "17:00",
  "maxDepth": 3,
  "excludePatterns": [],
  "excludeRepos": [],
  "notificationEnabled": true
}
```

### Advanced Configuration

For power users with complex project structures:

```json
{
  "projectsRoot": "~/code",
  "branchPrefix": "john-*",
  "syncTime": "18:00",
  "maxDepth": 5,
  "excludePatterns": ["archived/*", "*/node_modules", "*/.venv", "*/vendor", "*/.terraform", "experiments/*"],
  "excludeRepos": ["~/code/personal/old-project", "~/code/client-x/deprecated-app"],
  "gitConfigRepo": "git@github.com:myusername/dotfiles.git",
  "autoStashRemaining": false,
  "notificationEnabled": true,
  "logLevel": "info"
}
```

---

## Customizing Behavior

### Change Sync Time

```bash
# Edit config
vim ~/.git-sync-utils/config.json

# Change "syncTime": "17:00" to your preferred time
# Save and cron will use new time next day
```

### Exclude a Directory Tree

```bash
# Edit config
vim ~/.git-sync-utils/config.json

# Add to excludePatterns:
{
  "excludePatterns": [
    "archived/*",          # All archived folders
    "*/vendor",            # All vendor folders
    "experiments/failed/*" # Specific path
  ]
}
```

### Add Multiple Branch Patterns

While the config only supports one `branchPrefix`, you can use wildcards:

```json
{
  "branchPrefix": "*" // Sync ALL branches (use with caution!)
}
```

Or match multiple prefixes by using regex-style patterns:

```json
{
  "branchPrefix": "(john|dev|feature)/*" // Requires testing
}
```

---

## Testing Without Side Effects

### Dry Run Mode

Preview what would happen without making any changes:

```bash
git-sync --dry-run
```

Output shows what _would_ be synced, but:

- No commits created
- No pushes executed
- No stashes created
- Safe to run anytime

### Status Check Only

See what needs syncing without running the sync:

```bash
git-sync --status
```

---

## Integration with Other Tools

### Pre-commit Hooks

Add secret scanning to _all_ your commits:

```bash
# In any repo
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
source ~/.git-sync-utils/lib/git-ops.sh
check_for_secrets || exit 1
EOF

chmod +x .git/hooks/pre-commit
```

### Shell Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Quick sync alias
alias gs='git-sync'

# Status at a glance
alias gss='git-sync --status'

# Morning routine: pull all repos
alias gm='cd ~/projects && for d in */; do (cd "$d" && git pull); done'
```

### VS Code Integration

Create a task in `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Git Sync",
      "type": "shell",
      "command": "git-sync",
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    }
  ]
}
```

---

## Troubleshooting Quick Fixes

### "Configuration not found"

```bash
# Re-run installation
cd git-sync-utils
./install.sh
```

### "No repositories found"

```bash
# Check your branch name matches prefix
git branch --show-current

# View config to see expected prefix
git-sync --config

# Adjust either branch name or config
```

### "Push failed: authentication"

```bash
# Test SSH access
ssh -T git@github.com

# If fails, set up SSH key:
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
# Add to GitHub/GitLab/etc
```

### Notification not showing

```bash
# Test manually
~/.git-sync-utils/lib/send-reminder.sh

# Check cron
crontab -l | grep git-sync

# Reinstall cron entry
./install.sh
```

---

## Uninstallation

If you want to remove Git Sync Utility:

```bash
# Remove cron job
crontab -l | grep -v git-sync | crontab -

# Remove files
rm -rf ~/.git-sync-utils

# Remove from PATH (edit ~/.bashrc or ~/.zshrc)
# Delete the lines:
# export PATH="${PATH}:${HOME}/.git-sync-utils"

# Reload shell
source ~/.bashrc
```

---

## Next Steps

- [ ] Read full [README.md](README.md) for detailed documentation
- [ ] Customize your configuration for your workflow
- [ ] Set up Git config sync if working across multiple machines
- [ ] Share with your team if they face the same pain points
- [ ] Star the repo if you find it useful! ⭐

---

## Quick Reference Card

```
COMMANDS:
  git-sync              Run interactive sync
  git-sync --status     Check what needs syncing
  git-sync --dry-run    Preview without executing
  git-sync --config     Show configuration
  git-sync --help       Show help

INTERACTIVE OPTIONS:
  a  Add all changes
  i  Interactive staging (git add -p)
  s  Skip this repository
  q  Quit sync process

FILES:
  ~/.git-sync-utils/config.json    Configuration
  ~/.git-sync-utils/sync.log       Operation logs
  ~/.git-sync-utils/backups/       Config backups

WORKFLOW:
  1. Receive notification at EOD
  2. Run: git-sync
  3. Choose action for each repo
  4. Review summary
  5. Done! ✓
```

---

**That's it! You're ready to never lose uncommitted work again.** 🎉
