#!/bin/bash

# Directories
INPUT_DIR="input_folder"
OUTPUT_DIR="output_folder"

# Create the output folder if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Loop through all MP4 files in the input directory
for file in "$INPUT_DIR"/*.mp4; do
  [ -e "$file" ] || { echo "No MP4 files found in $INPUT_DIR"; exit 1; }

  # Extract the filename without extension
  filename=$(basename "$file" .mp4)

  # Define output path
  output="$OUTPUT_DIR/${filename}.wav"

  # Convert MP4 to WAV (stereo, 44100 Hz, 16-bit PCM)
  ffmpeg -i "$file" -vn -acodec pcm_s16le -ar 44100 -ac 2 "$output"

  echo "Converted $file -> $output"
done
