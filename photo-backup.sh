#!/usr/bin/env bash

# Google Shell Style Guide compliant backup script
# https://google.github.io/styleguide/shellguide.html

set -euo pipefail

readonly LOG_FILE="/var/log/photo-backup.log"
readonly SRC_1="/Volumes/PhotoStore"
readonly SRC_2="/Volumes/MorePhotos"
readonly TEMP_DIR="$(mktemp -d)"
readonly HOST="aurora"
readonly DEST_PATH="/mnt/storage/photos"

# Command line flags
dry_run_flag=""

# Initialize destination with proper hostname
declare -r destination
if ssh -q "${HOST}-local" exit; then
  destination="${HOST}-local:${DEST_PATH}"
else
  destination="${HOST}:${DEST_PATH}"
fi

trap 'rm -rf "${TEMP_DIR}"' EXIT

#######################################
# Validate filter file existence and content
# Arguments:
#   $1 - Path to filter file
#######################################
validate_filter_file() {
  local -r filter_file="$1"

  if [[ ! -f "${filter_file}" ]]; then
    log_message "FATAL: Filter file ${filter_file} not found" >&2
    exit 1
  fi

  if [[ ! -s "${filter_file}" ]]; then
    log_message "FATAL: Filter file ${filter_file} is empty" >&2
    exit 1
  fi
}

#######################################
# Show usage information.
#######################################
show_usage() {
  cat <<EOF
Usage: ${0##*/} [--dry-run]
Sync photos from two sources to backup server with protection rules.

Options:
  --dry-run    Show what would be transferred without making changes
  --help       Show this help message

Safety features:
  - Verifies both source directories are mounted and non-empty
  - Validates protection filter file existence and content
  - Prevents accidental deletions through protection rules
EOF
}

#######################################
# Log a message to stdout and log file.
# Arguments:
#   $1 - Message to log
#######################################
log_message() {
  local -r msg="$1"
  printf "%s\n" "${msg}" | tee -a "${LOG_FILE}"
}

#######################################
# Verify directory exists and is non-empty.
# Arguments:
#   $1 - Directory path to verify
#######################################
verify_source_directory() {
  local -r dir="$1"
  
  if [[ ! -d "${dir}" ]]; then
    log_message "Error: Source directory ${dir} not mounted" >&2
    exit 1
  fi

  if ! find "${dir}" -mindepth 1 -print -quit | grep -q .; then
    log_message "Error: Source directory ${dir} appears empty!" >&2
    exit 1
  fi
}

#######################################
# Log and execute a command.
# Globals:
#   LOG_FILE
# Arguments:
#   $@ - Command to execute
#######################################
run_command() {
  printf "Running: %s\n" "$*" | tee -a "${LOG_FILE}"
  "$@" | tee -a "${LOG_FILE}"
}

#######################################
# Clean directory of temporary files.
# Arguments:
#   $1 - Directory to clean
#   $2 - File pattern to remove
#######################################
remove_files() {
  local -r dir="$1"
  local -r pattern="$2"

  log_message "Deleting ${pattern} files from ${dir}"
  run_command find "${dir}" -name "${pattern}" -delete -print
}

#######################################
# Clean directory of macOS-specific temporary files.
# Arguments:
#   $1 - Directory to clean
#######################################
clean_directory() {
  local -r dir="$1"

  remove_files "${dir}" '.DS_Store'
  remove_files "${dir}" '*_original'
  run_command dot_clean -v "${dir}"
}

#######################################
# Generate rsync protection filter rules.
# Arguments:
#   $1 - Source directory to protect
#   $2 - Output filter file path
#######################################
generate_protection_filter() {
  local -r protect_src="$1"
  local -r filter_file="$2"

  find "${protect_src}" -mindepth 1 -print0 | while IFS= read -r -d '' path; do
    local relative_path="${path#"${protect_src}/"}"
    printf "P /%s\n" "${relative_path}"
  done > "${filter_file}" || {
    log_message "Error: Failed to generate filter rules for ${protect_src}" >&2
    exit 1
  }
}

#######################################
# Perform backup with file protection.
# Arguments:
#   $1 - Source directory to backup
#   $2 - Directory containing files to protect
#######################################
perform_backup() {
  local -r source_dir="$1"
  local -r protect_dir="$2"
  local -r filter_file="${TEMP_DIR}/filter.rules"

  log_message "Generating protection rules for ${protect_dir} in ${filter_file}"
  generate_protection_filter "${protect_dir}" "${filter_file}"
  validate_filter_file "${filter_file}"

  log_message "Backing up ${source_dir} to ${HOST}"
  run_command rsync -aHv --progress \
    --exclude '.*' \
    --filter="merge ${filter_file}" \
    --delete \
    ${dry_run_flag} \
    "${source_dir}/" "${destination}"
}

main() {
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run_flag="--dry-run"
        shift
        ;;
      --help)
        show_usage
        exit 0
        ;;
      *)
        log_message "Error: Invalid option '$1'" >&2
        show_usage
        exit 1
        ;;
    esac
  done

  # Verify source directories
  verify_source_directory "${SRC_1}"
  verify_source_directory "${SRC_2}"

  # Execute backup process
  {
    log_message "BEGIN $(date)"
    clean_directory "${SRC_1}"
    clean_directory "${SRC_2}"
    perform_backup "${SRC_1}" "${SRC_2}"
    perform_backup "${SRC_2}" "${SRC_1}"
    log_message "END $(date)"
  }
}

main "$@"
