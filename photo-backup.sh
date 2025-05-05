#!/usr/bin/env bash

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

# Clean up temporary directory on exit
trap 'rm -rf "${TEMP_DIR}"' EXIT

#######################################
# Log command output and write to log file.
# Arguments:
#   Command to execute
#######################################
log_command() {
  local -r cmd=("$@")
  printf "Running: %s\n" "${cmd[*]}" | tee -a "${LOG_FILE}"
  "${cmd[@]}" | tee -a "${LOG_FILE}"
}

#######################################
# Remove specific file patterns from directory.
# Arguments:
#   $1 - Directory to clean
#   $2 - File pattern to remove
#######################################
remove_files() {
  local -r dir="$1"
  local -r pattern="$2"
  
  log_command printf "Deleting %s files from %s\n" "${pattern}" "${dir}"
  log_command find "${dir}" -name "${pattern}" -delete -print
}

#######################################
# Clean directory of temporary and macOS-specific files.
# Arguments:
#   $1 - Directory to clean
#######################################
clean_directory() {
  local -r dir="$1"
  
  remove_files "${dir}" '.DS_Store'
  remove_files "${dir}" '*_original'
  log_command dot_clean -v "${dir}"
}

#######################################
# Generate rsync filter rules to protect existing files.
# Arguments:
#   $1 - Source directory to protect
#   $2 - Output filter file path
#######################################
generate_protection_filter() {
  local -r protect_src="$1"
  local -r filter_file="$2"
  
  find "${protect_src}" -mindepth 1 | while IFS= read -r -d '' path; do
    local relative_path="${path#"${protect_src}/"}"
    printf "P /%s\n" "${relative_path}"
  done > "${filter_file}"
}

#######################################
# Perform backup with protection for existing files.
# Arguments:
#   $1 - Source directory to backup
#   $2 - Directory containing files to protect
#######################################
perform_backup() {
  local -r source_dir="$1"
  local -r protect_dir="$2"
  local -r filter_file="${TEMP_DIR}/filter.rules"

  log_command printf "Generating protection rules for %s\n" "${protect_dir}"
  generate_protection_filter "${protect_dir}" "${filter_file}"

  log_command printf "Backing up %s to %s\n" "${source_dir}" "${HOST}"
  log_command rsync -aHv --progress \
    --exclude '.*' \
    --filter="merge ${filter_file}" \
    --delete \
    "${source_dir}/" "${DESTINATION}"
}

main() {
  # Verify source directories exist
  for dir in "${SRC_1}" "${SRC_2}"; do
    if [[ ! -d "${dir}" ]]; then
      printf "Error: Source directory %s not mounted\n" "${dir}" >&2
      exit 1
    fi
  done

  {
    printf "BEGIN %s\n" "$(date)"
    clean_directory "${SRC_1}"
    clean_directory "${SRC_2}"
    perform_backup "${SRC_1}" "${SRC_2}"
    perform_backup "${SRC_2}" "${SRC_1}"
    printf "END %s\n" "$(date)"
  } | tee -a "${LOG_FILE}"
}

main "$@"