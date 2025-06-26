#!/bin/bash

# Configuration
INPUT_DIR="input_folder"
OUTPUT_DIR="output_folder"
HLS_TIME=10          # Segment duration in seconds
HLS_LIST_SIZE=0      # 0 means keep all segments in playlist

# Supported audio formats
SUPPORTED_FORMATS=("*.mp3" "*.wav" "*.flac" "*.m4a" "*.aac" "*.ogg")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    print_error "ffmpeg is not installed or not in PATH"
    exit 1
fi

# Check if input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    print_error "Input directory '$INPUT_DIR' does not exist"
    exit 1
fi

# Create the output folder if it doesn't exist
mkdir -p "$OUTPUT_DIR"
print_status "Created output directory: $OUTPUT_DIR"

# Counter for processed files
processed_count=0
error_count=0

# Function to convert a single file
convert_file() {
    local file="$1"
    local filename=$(basename "$file")
    local name_without_ext="${filename%.*}"
    
    # Create a subdirectory for each file in the output folder
    local subfolder="$OUTPUT_DIR/$name_without_ext"
    mkdir -p "$subfolder"
    
    # Define output paths for .m3u8 file in the subdirectory
    local m3u8output="$subfolder/${name_without_ext}.m3u8"
    
    print_status "Converting: $filename"
    
    # Convert to HLS (.m3u8 and .ts segments) and store in the subdirectory
    if ffmpeg -i "$file" \
        -c:a aac \
        -b:a 128k \
        -ar 44100 \
        -start_number 0 \
        -hls_time $HLS_TIME \
        -hls_list_size $HLS_LIST_SIZE \
        -hls_segment_filename "$subfolder/${name_without_ext}_%03d.ts" \
        -f hls "$m3u8output" \
        -y 2>/dev/null; then
        
        print_success "Converted '$filename' → '$subfolder/'"
        ((processed_count++))
    else
        print_error "Failed to convert '$filename'"
        ((error_count++))
    fi
}

# Process all supported audio formats
found_files=false

for format in "${SUPPORTED_FORMATS[@]}"; do
    # Use nullglob to handle cases where no files match the pattern
    shopt -s nullglob
    files=("$INPUT_DIR"/$format)
    shopt -u nullglob
    
    if [ ${#files[@]} -gt 0 ]; then
        found_files=true
        for file in "${files[@]}"; do
            if [ -f "$file" ]; then
                convert_file "$file"
            fi
        done
    fi
done

# Summary
echo
print_status "=== CONVERSION SUMMARY ==="
if [ "$found_files" = false ]; then
    print_warning "No supported audio files found in '$INPUT_DIR'"
    print_status "Supported formats: ${SUPPORTED_FORMATS[*]}"
else
    print_success "Successfully processed: $processed_count files"
    if [ $error_count -gt 0 ]; then
        print_error "Failed to process: $error_count files"
    fi
    print_status "Output directory: $OUTPUT_DIR"
fi

echo
print_status "Done!"