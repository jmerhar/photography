#!/usr/bin/env bash

# Google Shell Style Guide compliant backup script
# https://google.github.io/styleguide/shellguide.html

set -euo pipefail

########################################
# Default Configuration (override with CLI options)
########################################
readonly LOG_FILE="/var/log/photo-backup.log"
readonly TEMP_DIR="$(mktemp -d)"
readonly DEFAULT_SRC_1="/Volumes/PhotoStore"
readonly DEFAULT_SRC_2="/Volumes/MorePhotos"
readonly DEFAULT_HOST="aurora"
readonly DEFAULT_DEST_PATH="/mnt/storage/photos"

########################################
# Runtime Configuration (set via CLI options)
########################################
SRC_1="${DEFAULT_SRC_1}"
SRC_2="${DEFAULT_SRC_2}"
HOST="${DEFAULT_HOST}"
DEST_PATH="${DEFAULT_DEST_PATH}"
DRY_RUN_FLAG=""
DEBUG_MODE="false"
DESTINATION=""  # Will be set in parse_options

trap 'rm -rf "${TEMP_DIR}"' EXIT

#######################################
# Show usage information.
#######################################
show_usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]
Sync photos from two sources to backup server with protection rules.

Options:
  -1 PATH       Source 1 path (default: ${DEFAULT_SRC_1})
  -2 PATH       Source 2 path (default: ${DEFAULT_SRC_2})
  -H HOST       Backup server hostname (default: ${DEFAULT_HOST})
  -p PATH       Destination path (default: ${DEFAULT_DEST_PATH})
  -n            Dry-run mode
  -d            Debug mode
  -h            Show this help message

Safety features:
  - Verifies source directories are mounted and non-empty
  - Validates protection filter file existence and content
  - Prevents accidental deletions through protection rules
EOF
}

#######################################
# Parse command line options
#######################################
parse_options() {
  while getopts "1:2:H:p:ndh" opt; do
    case "${opt}" in
      1) SRC_1="${OPTARG}" ;;
      2) SRC_2="${OPTARG}" ;;
      H) HOST="${OPTARG}" ;;
      p) DEST_PATH="${OPTARG}" ;;
      n) DRY_RUN_FLAG="--dry-run" ;;
      d) DEBUG_MODE="true" ;;
      h) show_usage; exit 0 ;;
      *) log_message "Error: Invalid option -${OPTARG}" >&2; show_usage; exit 1 ;;
    esac
  done
  shift $((OPTIND -1))

  if [[ $# -gt 0 ]]; then
    log_message "Error: Unexpected arguments: $*" >&2
    show_usage
    exit 1
  fi

  # Set final destination
  DESTINATION="${HOST}:${DEST_PATH}"
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
#   LOG_FILE, DEBUG_MODE
# Arguments:
#   $@ - Command to execute
#######################################
run_command() {
  local -r cmd_str="Running: $*"

  # Log command to file (always) and stdout (only in debug mode)
  if [[ "${DEBUG_MODE}" == "true" ]]; then
    log_message "${cmd_str}"
  else
    printf "%s\n" "${cmd_str}" >> "${LOG_FILE}"
  fi

  # Execute command and capture output
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

  log_message "Generating protection rules for ${protect_src}"
  find "${protect_src}" -mindepth 1 -print0 | while IFS= read -r -d '' path; do
    local relative_path="${path#"${protect_src}/"}"
    printf "P /%s\n" "${relative_path}"
  done > "${filter_file}" || {
    log_message "Error: Failed to generate filter rules for ${protect_src}" >&2
    exit 1
  }
}

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
# Perform backup with file protection.
# Arguments:
#   $1 - Source directory to backup
#   $2 - Directory containing files to protect
#######################################
perform_backup() {
  local -r source_dir="$1"
  local -r protect_dir="$2"
  local -r filter_file="${TEMP_DIR}/filter.rules"

  generate_protection_filter "${protect_dir}" "${filter_file}"
  validate_filter_file "${filter_file}"

  log_message "Backing up ${source_dir} to ${HOST}"
  run_command rsync -aHv --progress \
    --exclude '.*' \
    --filter="merge ${filter_file}" \
    --delete \
    ${DRY_RUN_FLAG} \
    "${source_dir}/" "${DESTINATION}"
}

main() {
  parse_options "$@"

  # Verify source directories
  verify_source_directory "${SRC_1}"
  verify_source_directory "${SRC_2}"

  # Execute backup process
  {
    log_message "BEGIN $(date)"
    log_message "Going to backup ${SRC_1} and ${SRC_2} to ${DESTINATION}"

    # Skip cleanups in dry-run mode
    if [[ -z "${DRY_RUN_FLAG}" ]]; then
      clean_directory "${SRC_1}"
      clean_directory "${SRC_2}"
    fi

    perform_backup "${SRC_1}" "${SRC_2}"
    perform_backup "${SRC_2}" "${SRC_1}"
    log_message "END $(date)"
  }
}

main "$@"
