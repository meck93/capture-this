#!/usr/bin/env bash
set -euo pipefail

CATALOG_PATH="${1:-apps/macos/Resources/Localizable.xcstrings}"

if [[ ! -f "${CATALOG_PATH}" ]]; then
  echo "Localization catalog not found: ${CATALOG_PATH}" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to validate ${CATALOG_PATH}" >&2
  exit 1
fi

jq empty "${CATALOG_PATH}"

missing_english="$(jq -r '
  .strings
  | to_entries[]
  | select((.value.localizations.en.stringUnit.value // "") == "")
  | .key
' "${CATALOG_PATH}")"

missing_german="$(jq -r '
  .strings
  | to_entries[]
  | select((.value.localizations.de.stringUnit.value // "") == "")
  | .key
' "${CATALOG_PATH}")"

if [[ -n "${missing_english}" || -n "${missing_german}" ]]; then
  echo "Localization validation failed for ${CATALOG_PATH}:" >&2

  if [[ -n "${missing_english}" ]]; then
    echo "Missing English translations:" >&2
    while IFS= read -r key; do
      printf '  %s\n' "${key}" >&2
    done <<< "${missing_english}"
  fi

  if [[ -n "${missing_german}" ]]; then
    echo "Missing German translations:" >&2
    while IFS= read -r key; do
      printf '  %s\n' "${key}" >&2
    done <<< "${missing_german}"
  fi

  exit 1
fi

key_count="$(jq '.strings | length' "${CATALOG_PATH}")"
echo "Localization validation passed: ${key_count} keys have English and German translations."
