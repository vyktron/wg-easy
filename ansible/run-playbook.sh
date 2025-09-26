#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLAYBOOK="${SCRIPT_DIR}/playbooks/deploy-wg-easy.yml"
DEFAULT_INVENTORY="${SCRIPT_DIR}/inventory.ini"
ANSIBLE_CFG="${PROJECT_ROOT}/ansible.cfg"

usage() {
  cat <<'EOF'
Usage: run-playbook.sh [options] [-- <additional ansible-playbook args>]

Options:
  -i, --inventory PATH   Inventory file to use (default: ansible/inventory.ini)
  -l, --limit TARGET     Limit execution to a host or group
  -h, --help             Show this help and exit

Any other arguments are passed directly to ansible-playbook. Use -- to
separate options intended for ansible-playbook when necessary.
EOF
}

inventory_path="${DEFAULT_INVENTORY}"
extra_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--inventory)
      if [[ $# -lt 2 ]]; then
        echo "Error: --inventory requires a path" >&2
        exit 1
      fi
      inventory_path="$2"
      shift 2
      ;;
    -l|--limit)
      if [[ $# -lt 2 ]]; then
        echo "Error: --limit requires a target" >&2
        exit 1
      fi
      extra_args+=("--limit" "$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_args+=("$@")
      break
      ;;
    *)
      extra_args+=("$1")
      shift
      ;;
  esac
 done

if [[ ! -f "${PLAYBOOK}" ]]; then
  echo "Error: playbook not found at ${PLAYBOOK}" >&2
  exit 1
fi

if [[ ! -f "${inventory_path}" ]]; then
  echo "Error: inventory file not found at ${inventory_path}" >&2
  echo "Copy ansible/inventory.example.ini to ansible/inventory.ini and adjust it." >&2
  exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Error: ansible-playbook command not found. Install Ansible before running this script." >&2
  exit 1
fi

export ANSIBLE_CONFIG="${ANSIBLE_CFG}"

exec ansible-playbook "${PLAYBOOK}" -i "${inventory_path}" "${extra_args[@]}" --ask-become-pass --ask-pass
