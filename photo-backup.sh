#!/usr/bin/env bash

# Following Google's style guide:
# https://google.github.io/styleguide/shellguide.html

set -euo pipefail

readonly LOG_FILE="/var/log/photo-backup.log"
readonly SRC_1="/Volumes/PhotoStore"
readonly SRC_2="/Volumes/MorePhotos"
readonly TEMP_DIR="$(mktemp -d)"

readonly HOST="aurora"
DESTINATION=""
# shellcheck disable=SC2310
if ssh -q "${HOST}-local" exit; then
  DESTINATION="${HOST}-local:/mnt/storage/photos"
else
  DESTINATION="${HOST}:/mnt/storage/photos"
fi

trap 'rm -rf "${TEMP_DIR}"' EXIT

#######################################
# Log a message to stdout and log file
# Arguments:
#   Message to log
#######################################
log_message() {
  local -r msg="$1"
  printf "%s\n" "${msg}" | tee -a "${LOG_FILE}"
}

#######################################
# Log and execute a command
# Arguments:
#   Command to execute (passed as array)
#######################################
run_command() {
  local -r cmd=("$@")
  log_message "Running: ${cmd[*]}"
  "${cmd[@]}" | tee -a "${LOG_FILE}"
}

#######################################
# Remove specific file patterns from directory
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
# Clean directory of temporary files
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
# Generate rsync protection filter rules
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
    log_message "Error: Failed to generate filter rules for ${protect_src}"
    exit 1
  }
}

#######################################
# Perform backup with file protection
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

  # Critical safety check
  if [[ ! -f "${filter_file}" ]]; then
    log_message "FATAL ERROR: Filter file ${filter_file} not found! Aborting backup."
    exit 1
  fi

  if [[ ! -s "${filter_file}" ]]; then
    log_message "WARNING: Filter file is empty! This might indicate a problem with the protection rules."
  fi

  log_message "Backing up ${source_dir} to ${HOST}"
  run_command rsync -aHv --progress \
    --exclude '.*' \
    --filter="merge ${filter_file}" \
    --delete \
    "${source_dir}/" "${DESTINATION}"
}

main() {
  # Verify source directories exist
  for dir in "${SRC_1}" "${SRC_2}"; do
    if [[ ! -d "${dir}" ]]; then
      log_message "Error: Source directory ${dir} not mounted" >&2
      exit 1
    fi
  done

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