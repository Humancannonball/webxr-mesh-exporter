#!/bin/bash
# Batch convert WebXR exports to URDF
# Usage: ./convert_to_urdf.sh [input_directory] [output_directory]

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
INPUT_DIR="${1:-exports}"
OUTPUT_DIR="${2:-urdf_exports}"

echo "Converting WebXR exports to URDF..."
echo "Input directory: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo

# Run the Python converter
python3 "$SCRIPT_DIR/json_to_urdf.py" "$INPUT_DIR" -o "$OUTPUT_DIR"

echo
echo "Conversion complete! URDF files are in: $OUTPUT_DIR"
