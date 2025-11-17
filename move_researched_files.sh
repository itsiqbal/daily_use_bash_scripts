#!/usr/bin/env bash

set -o pipefail

LOG_FILE="./move_researched_files.log"
CONFIG_FILE="${HOME}/.move-researched-files.conf"
METADATA_FILE=".move-researched-files-metadata.json"

# Default config values
PRESERVE_STRUCTURE="true"
AUTO_CLEANUP_EMPTY="true"
DEFAULT_MODE="move"

function log_history() {
  local msg="${1}"
  printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "${msg}" >> "${LOG_FILE}"
}

function log_message() {
  echo "  ${1}"
}

function log_error() {
  echo "❌ ${1}" >&2
}

function log_title() {
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  ${1}"
  echo "═══════════════════════════════════════════════════════════"
}

function log_header() {
  echo ""
  echo "─── ${1} ───"
}

function load_config() {
  if [[ -f "${CONFIG_FILE}" ]]; then
    source "${CONFIG_FILE}"
  fi
}

function print_usage() {
  cat <<EOF
Usage: move_researched_files.sh [OPTIONS] <store|restore> <from_dir> <to_dir>

Move or copy .md files between directories with structure preservation.

Commands:
  store     Move/copy files from working directory to archive (creates archive)
  restore   Move/copy files from archive back to working directory

Options:
  --dry-run           Show what would happen without making changes
  --copy              Copy files instead of moving them
  --flat              Don't preserve directory structure (flat storage)
  --restore-exact     Restore files to their exact original locations (requires metadata)
  --no-cleanup        Don't remove empty directories after moving
  -h, --help          Show this help message

Configuration:
  Config file: ${CONFIG_FILE}
  Options: PRESERVE_STRUCTURE, AUTO_CLEANUP_EMPTY, DEFAULT_MODE

Examples:
  move_researched_files.sh store ./proj ./archive
  move_researched_files.sh --copy store ./proj ./archive
  move_researched_files.sh --restore-exact restore ./archive ./proj
  move_researched_files.sh --dry-run --flat store ./proj ./archive
EOF
}

function ensure_dir_exists_or_create() {
  local dir="${1}"
  if [[ ! -d "${dir}" ]]; then
    log_message "Creating directory: '${dir}'"
    mkdir -p -- "${dir}"
  fi
}

function ensure_dir() {
  local dir="${1}"
  if [[ ! -d "${dir}" ]]; then
    log_error "ERROR: Directory does not exist: '${dir}'"
    exit 1
  fi
}

function get_relative_path() {
  local file="${1}"
  local base_dir="${2}"
  
  # Get absolute paths
  local abs_file abs_base
  abs_file="$(cd "$(dirname "${file}")" && pwd)/$(basename "${file}")"
  abs_base="$(cd "${base_dir}" && pwd)"
  
  # Remove base from file path
  echo "${abs_file#${abs_base}/}"
}

function save_metadata() {
  local src="${1}"
  local dst="${2}"
  local from_dir="${3}"
  local to_base_dir="${4}"
  local metadata_path="${to_base_dir}/${METADATA_FILE}"
  
  local rel_path
  rel_path="$(get_relative_path "${src}" "${from_dir}")"
  
  local entry
  entry=$(cat <<EOF
{
  "source": "${src}",
  "relative_path": "${rel_path}",
  "destination": "${dst}",
  "timestamp": "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')",
  "original_base": "${from_dir}"
}
EOF
)
  
  # Append to metadata file
  if [[ -f "${metadata_path}" ]]; then
    # Remove closing bracket, add comma and new entry
    sed -i.bak '$ d' "${metadata_path}" && rm -f "${metadata_path}.bak"
    echo "," >> "${metadata_path}"
    echo "${entry}" >> "${metadata_path}"
    echo "]" >> "${metadata_path}"
  else
    echo "[" > "${metadata_path}"
    echo "${entry}" >> "${metadata_path}"
    echo "]" >> "${metadata_path}"
  fi
}

function get_target_path() {
  local src="${1}"
  local from_dir="${2}"
  local to_dir="${3}"
  local preserve_structure="${4}"
  
  if [[ "${preserve_structure}" == "true" ]]; then
    local rel_path
    rel_path="$(get_relative_path "${src}" "${from_dir}")"
    echo "${to_dir}/${rel_path}"
  else
    echo "${to_dir}/$(basename "${src}")"
  fi
}

function safe_move_or_copy() {
  local src="${1}"
  local target="${2}"
  local operation="${3}"  # "move" or "copy"
  local from_dir="${4}"
  local to_dir="${5}"
  
  # Create target directory
  local target_dir
  target_dir="$(dirname "${target}")"
  
  if [[ "${dry_run}" != "1" ]]; then
    mkdir -p -- "${target_dir}"
  fi
  
  # Handle duplicate filenames - create one backup and replace
  if [[ -e "${target}" ]]; then
    local base ext backup_file
    base="$(basename "${target%.*}")"
    ext="${target##*.}"
    
    if [[ "${base}" == "$(basename "${target}")" ]]; then
      # No extension
      backup_file=".${target}.backup"
    else
      backup_file="${target_dir}/.${base}.backup.${ext}"
    fi
    
    # Create backup only if it doesn't exist
    if [[ ! -e "${backup_file}" && "${dry_run}" != "1" ]]; then
      cp -- "${target}" "${backup_file}"
      log_message "Created backup: '${backup_file}'"
      log_history "Created backup: '${backup_file}'"
    fi
  fi
  
  if [[ "${dry_run}" == "1" ]]; then
    log_message "[dry-run] Would ${operation} '${src}' → '${target}'"
    log_history "[dry-run] ${operation} '${src}' → '${target}'"
  else
    if [[ "${operation}" == "copy" ]]; then
      cp -- "${src}" "${target}"
      log_message "Copied '${src}' → '${target}'"
      log_history "Copied '${src}' → '${target}'"
    else
      mv -- "${src}" "${target}"
      log_message "Moved '${src}' → '${target}'"
      log_history "Moved '${src}' → '${target}'"
    fi
    
    # Save metadata (pass the base to_dir, not the target file)
    save_metadata "${src}" "${target}" "${from_dir}" "${to_dir}"
  fi
}

function restore_exact() {
  local from_dir="${1}"
  local to_dir="${2}"
  local metadata_path="${from_dir}/${METADATA_FILE}"
  
  if [[ ! -f "${metadata_path}" ]]; then
    log_error "ERROR: Metadata file not found: '${metadata_path}'"
    log_error "Cannot use --restore-exact without metadata. Use regular restore instead."
    exit 1
  fi
  
  log_message "Restoring from metadata: '${metadata_path}'"
  
  # Parse JSON metadata (simple grep-based parsing for bash)
  files=()
  while IFS= read -r line; do
    files+=("${line}")
  done < <(find "${from_dir}" -type f \( -name "*.md" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/vendor/*" \
    -not -path "*/.venv/*" \
    -not -path "*/venv/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.git/*" \
    -not -path "*/dist/*" \
    -not -name "README.md"\
    -not -path "*/build/*")
  
  for f in "${files[@]}"; do
    # Skip metadata file itself
    [[ "$(basename "${f}")" == "${METADATA_FILE}" ]] && continue
    
    # Extract relative path from metadata
    local rel_path
    rel_path=$(grep -A 3 "\"destination\": \"${f}\"" "${metadata_path}" | grep "relative_path" | cut -d'"' -f4)
    
    if [[ -n "${rel_path}" ]]; then
      local target="${to_dir}/${rel_path}"
      safe_move_or_copy "${f}" "${target}" "${operation_mode}" "${from_dir}" "${to_dir}"
    else
      log_message "Warning: No metadata found for '${f}', using filename only"
      safe_move_or_copy "${f}" "${to_dir}/$(basename "${f}")" "${operation_mode}" "${from_dir}" "${to_dir}"
    fi
  done
}

function cleanup_empty_dirs() {
  local base_dir="${1}"
  
  if [[ "${auto_cleanup}" != "true" ]]; then
    return
  fi
  
  log_message "Cleaning up empty directories in '${base_dir}'..."
  
  if [[ "${dry_run}" == "1" ]]; then
    find "${base_dir}" -type d -empty -print | while read -r dir; do
      log_message "[dry-run] Would remove empty directory: '${dir}'"
    done
  else
    find "${base_dir}" -type d -empty -delete
    log_message "Empty directories removed"
  fi
}

# --- Load Configuration ---
load_config

# --- Parse Arguments ---
dry_run="0"
preserve_structure="${PRESERVE_STRUCTURE}"
auto_cleanup="${AUTO_CLEANUP_EMPTY}"
operation_mode="${DEFAULT_MODE}"
restore_exact_mode="false"

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --dry-run)
      dry_run="1"
      shift
      ;;
    --copy)
      operation_mode="copy"
      shift
      ;;
    --flat)
      preserve_structure="false"
      shift
      ;;
    --restore-exact)
      restore_exact_mode="true"
      shift
      ;;
    --no-cleanup)
      auto_cleanup="false"
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -ne 3 ]]; then
  print_usage
  exit 1
fi

action="${1}"
from_dir="${2}"
to_dir="${3}"

log_title "Move Researched + .md files Utility"
log_header "Configuration"
log_message "$(
  cat <<EOF
            dry_run: '${dry_run}'
             action: '${action}'
          from_dir: '${from_dir}'
            to_dir: '${to_dir}'
  preserve_structure: '${preserve_structure}'
      operation_mode: '${operation_mode}'
   restore_exact_mode: '${restore_exact_mode}'
       auto_cleanup: '${auto_cleanup}'
EOF
)"

# Directory logic
if [[ "${action}" == "store" ]]; then
  ensure_dir "${from_dir}"
  ensure_dir_exists_or_create "${to_dir}"
elif [[ "${action}" == "restore" ]]; then
  ensure_dir "${from_dir}"
  ensure_dir_exists_or_create "${to_dir}"
else
  log_error "ERROR: Invalid action '${action}'"
  exit 1
fi

# --- Execute based on mode ---
if [[ "${action}" == "restore" && "${restore_exact_mode}" == "true" ]]; then
  restore_exact "${from_dir}" "${to_dir}"
else
  # --- Recursive file search (excluding dependency directories) ---
  files=()
  while IFS= read -r line; do
    files+=("${line}")
  done < <(find "${from_dir}" -type f \( -name "*.md" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/vendor/*" \
    -not -path "*/.venv/*" \
    -not -path "*/venv/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.git/*" \
    -not -path "*/dist/*" \
    -not -name "README.md"\
    -not -path "*/build/*")
  
  if [[ ${#files[@]} -eq 0 ]]; then
    log_message "No .md files found in '${from_dir}'. Nothing to do."
    exit 0
  fi
  
  log_header "Processing Files"
  log_message "Found ${#files[@]} file(s) to process"
  
  for f in "${files[@]}"; do
    # Skip metadata file
    [[ "$(basename "${f}")" == "${METADATA_FILE}" ]] && continue
    
    target="$(get_target_path "${f}" "${from_dir}" "${to_dir}" "${preserve_structure}")"
    safe_move_or_copy "${f}" "${target}" "${operation_mode}" "${from_dir}" "${to_dir}"
  done
fi

# Cleanup empty directories if moving (not copying)
if [[ "${operation_mode}" == "move" && "${action}" == "store" ]]; then
  cleanup_empty_dirs "${from_dir}"
fi

log_header "Done"
log_message "Operation '${action}' completed successfully."
log_history "Completed '${action}' (${operation_mode}) from '${from_dir}' to '${to_dir}'"


#example commands to execute
#copy_files ./move_researched_files.sh --copy store /$HOME/Desktop/projects/airasia/oms /$HOME/Desktop/projects/iqbal/dotfiles/markdowns/oms 
#copy_back_files ./move_researched_files.sh --copy store /$HOME/Desktop/projects/iqbal/dotfiles/markdowns/oms /$HOME/Desktop/projects/airasia/oms
