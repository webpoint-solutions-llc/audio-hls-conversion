#!/bin/bash

# Directories
INPUT_DIR="input_folder"
OUTPUT_DIR="output_folder"

# Create the output folder if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Loop through all MP3 files in the input directory
for file in "$INPUT_DIR"/*.wav; do
  # Extract the filename without extension
  filename=$(basename "$file" .wav)

  # Create a subdirectory for each file in the output folder
  subfolder="$OUTPUT_DIR/$filename"
  mkdir -p "$subfolder"

  # Define output paths for .m3u8 file in the subdirectory
  m3u8output="$subfolder/${filename}.m3u8"

  # Convert MP3 to HLS (.m3u8 and .ts segments) and store in the subdirectory
  ffmpeg -i "$file" -start_number 0 -hls_time 10 -hls_list_size 0 -hls_segment_filename "$subfolder/${filename}_%03d.ts" -f hls "$m3u8output"

  echo "Converted $file to $m3u8output in $subfolder"
done
