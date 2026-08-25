#!/usr/bin/env bash
# ==============================================================================
# run_all_verifications.sh
# Interactive Master Verification Runner for Kavacha
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Launch interactive Python runner
python3 "$SCRIPT_DIR/verify_results.py" "$@"
