#!/bin/bash
# Runs b50-sriov-alloc, using the custom Mesa build at /opt/mesa-intel if present.
# This is needed for Arc Pro B70 (0xe223) support on systems whose system Mesa
# predates 0xe223 PCI ID support (see README "Arc Pro B70 on older Mesa").

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_ICD="/opt/mesa-intel/share/vulkan/icd.d/intel_icd.x86_64.json"

if [ -f "$CUSTOM_ICD" ]; then
    export VK_ICD_FILENAMES="$CUSTOM_ICD"
fi

exec "$SCRIPT_DIR/build/b50-sriov-alloc" "$@"
