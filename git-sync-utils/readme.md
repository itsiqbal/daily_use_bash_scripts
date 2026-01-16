# Git Sync Utility

> **Automated end-of-day Git branch backup tool for developers working across multiple repositories**

Never lose uncommitted work again. Git Sync Utility helps you maintain backup hygiene by providing an interactive workflow to sync work-in-progress branches across multiple repositories at the end of each day.

---

## Features

### ✅ Core Functionality (MVP)

- **Auto-discovery** of Git repositories within configured directory
- **Branch filtering** to sync only branches matching your pattern (e.g., `username/*`)
- **Interactive staging** for uncommitted changes (add/skip/patch)
- **Commit + Push** flow with custom message input
- **Stash remainder** option for files you don't want to commit
- **Git config sync** from canonical repository
- **Daily reminders** via cron notifications

### 🎯 Design Philosophy

- **Reminder-driven, not auto-commit**: Cron sends notification at configured time; you run the sync interactively
- **Fail-safe by default**: Never force-push or perform destructive operations
- **Interactive control**: You decide what gets committed, what gets stashed, what gets skipped
- **Transparent operations**: See exactly what's happening at each step

---

## Installation

### Prerequisites

- Git 2.0+
- Bash 4.0+
- `jq` (will be auto-installed if possible)
- macOS or Linux

### Quick Install

```bash
# Clone the repository
git clone https://github.com/yourusername/git-sync-utils.git
cd git-sync-utils

# Run installation
./install.sh
```

### Installation Prompts

The installer will ask you:

1. **Projects root directory** (default: `~/projects`)

   - Where your Git repositories are located

2. **Branch prefix to sync** (default: `your-username/*`)

   - Only branches matching this pattern will be synced

3. **Daily sync reminder time** (default: `17:00`)

   - When you want to receive reminder notifications

4. **Git config repository URL** (optional)

   - Clone a canonical `.gitconfig` to sync across machines

5. **Maximum directory depth** (default: `3`)
   - How deep to search for repositories

### Post-Installation

Reload your shell configuration:

```bash
source ~/.bashrc  # or ~/.zshrc
```

Verify installation:

```bash
git-sync --version
```

---

## Usage

### Daily Workflow

At your configured time (default 5pm), you'll receive a notification showing how many repositories have uncommitted changes.

Run the sync:

```bash
git-sync
```

### Interactive Process

For each repository with changes, you'll see:

```
📦 myproject (branch: john/feature-x)

Modified files (2):
  src/app.js
  README.md

Untracked files (1):
  .env.local

[a] Add all and commit  [i] Interactive staging  [s] Skip repo  [q] Quit
>
```

**Options:**

- **`a` - Add all**: Stage all changes, commit, and push
- **`i` - Interactive**: Use `git add -p` for granular control
- **`s` - Skip**: Skip this repository for now
- **`q` - Quit**: Exit the sync process

After committing, handle remaining changes:

```
Remaining changes:
- .env.local

[stash] Stash with message  [skip] Leave unstaged
>
```

### Command-Line Options

```bash
git-sync                # Run interactive sync
git-sync --dry-run      # Preview what would be synced
git-sync --status       # Show repos with uncommitted changes
git-sync --config       # Display current configuration
git-sync --help         # Show help message
git-sync --version      # Show version
```

---

## Configuration

Configuration is stored in: `~/.git-sync-utils/config.json`

### Default Configuration

```json
{
  "projectsRoot": "~/projects",
  "branchPrefix": "username/*",
  "syncTime": "17:00",
  "maxDepth": 3,
  "excludePatterns": ["archived/*", "*/node_modules", "*/.venv", "*/vendor"],
  "gitConfigRepo": "",
  "excludeRepos": [],
  "autoStashRemaining": false,
  "notificationEnabled": true,
  "logLevel": "info"
}
```

### Configuration Options

| Option                | Type    | Description                                         |
| --------------------- | ------- | --------------------------------------------------- |
| `projectsRoot`        | string  | Root directory to search for repositories           |
| `branchPrefix`        | string  | Branch pattern to sync (supports `*` wildcard)      |
| `syncTime`            | string  | Daily reminder time (HH:MM, 24-hour format)         |
| `maxDepth`            | integer | Maximum directory depth to search (1-10)            |
| `excludePatterns`     | array   | Glob patterns for directories to skip               |
| `gitConfigRepo`       | string  | Git repository containing canonical `.gitconfig`    |
| `excludeRepos`        | array   | Specific repository paths to exclude                |
| `autoStashRemaining`  | boolean | Auto-stash remaining changes after commit           |
| `notificationEnabled` | boolean | Enable daily reminder notifications                 |
| `logLevel`            | string  | Logging verbosity: `debug`, `info`, `warn`, `error` |

### Editing Configuration

View current config:

```bash
git-sync --config
```

Edit manually:

```bash
vim ~/.git-sync-utils/config.json
```

### Excluding Repositories

Add a repository to the exclude list:

```bash
# Edit config.json and add to excludeRepos array
{
  "excludeRepos": [
    "~/projects/archived-project",
    "~/work/legacy-app"
  ]
}
```

Or use exclude patterns for entire directory trees:

```json
{
  "excludePatterns": ["archived/*", "*/vendor", "*/.terraform"]
}
```

---

## Advanced Usage

### Git Config Sync

Sync your Git configuration across machines:

1. Create a repository with your canonical `.gitconfig`:

```bash
# In a separate repo
git init git-config-repo
cp ~/.gitconfig git-config-repo/.gitconfig
cd git-config-repo
git add .gitconfig
git commit -m "Initial commit"
git remote add origin git@github.com:username/git-config.git
git push -u origin main
```

2. Add the repo URL to your config:

```bash
# Edit ~/.git-sync-utils/config.json
{
  "gitConfigRepo": "git@github.com:username/git-config.git"
}
```

3. Run install again or manually sync:

```bash
cd ~/.git-sync-utils/git-config-repo && git pull
```

**Note**: Config sync uses merge mode - your local settings are preserved, and changes are logged.

### Dry Run Mode

Preview what would be synced without making any changes:

```bash
git-sync --dry-run
```

### Checking Status

See which repositories need syncing:

```bash
git-sync --status
```

Output:

```
Repository Status
═══════════════════════════════════════

📦 project-alpha (branch: john/fix-bug)
  • 1 staged files
  • 3 modified files
  • 2 unpushed commits

📦 project-beta (branch: john/new-feature)
  • 5 modified files
  • 1 untracked files
```

---

## File Structure

```
~/.git-sync-utils/
├── config.json              # User configuration
├── sync.log                 # Operation logs
├── git-sync                 # Main executable
├── lib/
│   ├── ui.sh               # User interface functions
│   ├── config.sh           # Configuration management
│   ├── git-ops.sh          # Git operation wrappers
│   └── send-reminder.sh    # Notification script
├── backups/
│   └── gitconfig.backup.*  # Backed-up .gitconfig files
└── git-config-repo/        # Cloned config repository
    └── .gitconfig
```

---

## Safety Features

### Defensive Programming

- **Never force-push**: Uses `--force-with-lease` only when explicitly needed
- **Conflict detection**: Checks if remote has diverged before pushing
- **Large file warnings**: Alerts you before committing files >10MB
- **Secret scanning**: Warns about potential secrets in staged files
- **Backup on merge**: Creates timestamped backups before modifying `.gitconfig`

### Error Handling

- **Network failures**: Queued for manual retry
- **Merge conflicts**: Aborts push and notifies user
- **Detached HEAD**: Skips repository with warning
- **Missing remote**: Sets upstream branch on first push

### Logging

All operations are logged to `~/.git-sync-utils/sync.log`:

```
[2026-01-16 17:05:23] Starting repository discovery
[2026-01-16 17:05:25] Processing repository: ~/projects/app (john/feature)
[2026-01-16 17:05:45] Synced: ~/projects/app (add all)
[2026-01-16 17:06:10] Summary: synced=3, skipped=1, errors=0
```

---

## Troubleshooting

### Cron Job Not Triggering

1. Check if cron is running:

   ```bash
   sudo systemctl status cron  # Linux
   # or check macOS system logs
   ```

2. Verify cron entry:

   ```bash
   crontab -l | grep git-sync
   ```

3. Manually test reminder:
   ```bash
   ~/.git-sync-utils/lib/send-reminder.sh
   ```

### Notifications Not Appearing

**macOS:**

```bash
# Check notification permissions
# System Preferences → Notifications → Terminal (or your terminal app)
```

**Linux:**

```bash
# Ensure notify-send is installed
sudo apt-get install libnotify-bin
```

### Authentication Failures

Git Sync uses your existing Git credentials. If push fails:

1. Test Git authentication:

   ```bash
   git clone git@github.com:yourusername/test-repo.git
   ```

2. Use SSH instead of HTTPS:

   ```bash
   # Set remote to SSH
   git remote set-url origin git@github.com:user/repo.git
   ```

3. Configure SSH keys:
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ssh-add ~/.ssh/id_ed25519
   ```

### Repository Not Being Discovered

1. Check max depth setting:

   ```bash
   git-sync --config
   # Increase maxDepth if needed
   ```

2. Verify branch name matches prefix:

   ```bash
   cd your-repo
   git branch --show-current
   # Should match pattern in branchPrefix
   ```

3. Check exclude patterns:
   ```bash
   git-sync --config
   # Verify your repo isn't excluded
   ```

---

## Limitations & Known Issues

- **Cron requires system awake**: If your machine sleeps through sync time, reminder won't trigger until next day
- **No automatic conflict resolution**: Remote divergence requires manual merge
- **SSH key required for passwordless push**: HTTPS with password prompt won't work in cron context
- **macOS only for native notifications**: Linux requires `notify-send`
- **Single-user per machine**: Multi-user support coming in v2.0

---

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Follow the existing code style (defensive Bash, clear comments)
4. Test on both macOS and Linux if possible
5. Submit a pull request

### Development Setup

```bash
# Clone and test locally
git clone https://github.com/yourusername/git-sync-utils.git
cd git-sync-utils

# Test installation in sandbox
./install.sh

# Run with debug logging
LOG_LEVEL=debug git-sync
```

---

## Roadmap

### v1.1 (Post-MVP)

- [ ] Full dry-run mode with detailed preview
- [ ] Enhanced logging with rotation
- [ ] Skip list management UI
- [ ] Multi-user support

### v2.0 (Future)

- [ ] Conflict resolution assistance
- [ ] Selective repo sync (choose which repos in session)
- [ ] Slack/email notifications
- [ ] Rollback command
- [ ] Web dashboard for sync history

---

## License

MIT License - See LICENSE file for details

---

## Acknowledgments

Built with battle-tested Bash practices by developers who've debugged production scripts at 3 AM.

Inspired by the need to never lose uncommitted work again after that one time the laptop died before EOD commit.

---

## Support

- **Issues**: https://github.com/yourusername/git-sync-utils/issues
- **Discussions**: https://github.com/yourusername/git-sync-utils/discussions
- **Email**: support@example.com

---

**Remember**: This tool is a safety net, not a replacement for good Git hygiene. Commit early, commit often! 🚀
