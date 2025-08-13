#!/bin/bash

# This script sets up global Git aliases for conventional commit messages.
# It makes it easier to follow a consistent commit message format.
# Instead of typing 'git commit -m "[feat] message"', you can just type 'git feat "message"'.

echo "Setting up Git aliases for conventional commits..."

# feat: For when you introduce a new feature.
git config --global alias.feat '!f() { git commit -m "[feat] $1"; }; f'

# fix: For when you patch a bug.
git config --global alias.fix '!f() { git commit -m "[fix] $1"; }; f'

# docs: For changes to documentation (e.g., README, comments).
git config --global alias.docs '!f() { git commit -m "[docs] $1"; }; f'

# style: For code style changes that don't affect logic (e.g., formatting, linting).
git config --global alias.style '!f() { git commit -m "[style] $1"; }; f'

# refactor: For code changes that are not a bug fix or a new feature.
git config --global alias.refactor '!f() { git commit -m "[refactor] $1"; }; f'

# perf: For code changes that improve performance.
git config --global alias.perf '!f() { git commit -m "[perf] $1"; }; f'

# test: For adding or modifying tests.
git config --global alias.test '!f() { git commit -m "[test] $1"; }; f'

# build: For changes affecting the build system or external dependencies (e.g., npm, Maven).
git config --global alias.build '!f() { git commit -m "[build] $1"; }; f'

# ci: For changes to Continuous Integration (CI) configuration files and scripts.
git config --global alias.ci '!f() { git commit -m "[ci] $1"; }; f'

# chore: For routine tasks or maintenance that isn't user-facing.
git config --global alias.chore '!f() { git commit -m "[chore] $1"; }; f'

# revert: For when you revert a previous commit.
git config --global alias.revert '!f() { git commit -m "[revert] $1"; }; f'

echo "✅ All Git aliases have been successfully created."
echo "Try them out with a command like: git feat \"your new feature\""
