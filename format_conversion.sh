#!/bin/bash

# Configuration
INPUT_DIR="input_folder"
OUTPUT_DIR="output_folder"

# Supported input audio formats
SUPPORTED_FORMATS=("*.mp3" "*.flac" "*.m4a" "*.aac" "*.ogg" "*.wma" "*.opus" "*.wav")

# WAV output configuration (only used for non-WAV files)
SAMPLE_RATE=44100    # Sample rate in Hz (44100, 48000, etc.)
BIT_DEPTH=16         # Bit depth (16, 24, 32)
CHANNELS=2           # Number of channels (1=mono, 2=stereo)

# Naming configuration
RENAME_TO_SNAKE_CASE=true  # Set to true to convert names to snake_case (lowercase with underscores)

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

# Function to convert filename to snake_case
to_snake_case() {
    local filename="$1"
    # Convert to lowercase
    filename=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
    # Replace spaces with underscores
    filename=$(echo "$filename" | tr ' ' '_')
    # Remove special characters except underscores and hyphens
    filename=$(echo "$filename" | sed 's/[^a-z0-9_-]//g')
    # Clean up multiple consecutive underscores
    filename=$(echo "$filename" | sed 's/_\+/_/g')
    # Remove leading/trailing underscores
    filename=$(echo "$filename" | sed 's/^_//;s/_$//')
    echo "$filename"
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

# Function to process a single file
convert_file() {
    local file="$1"
    local filename=$(basename "$file")
    local name_without_ext="${filename%.*}"
    local extension="${filename##*.}"
    
    # Apply snake_case naming if enabled
    if [ "$RENAME_TO_SNAKE_CASE" = true ]; then
        name_without_ext=$(to_snake_case "$name_without_ext")
    fi
    
    # Define output path for .wav file
    local output_file="$OUTPUT_DIR/${name_without_ext}.wav"
    
    # Convert extension to lowercase for comparison
    local ext_lower=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
    
    # Check if the file is already a WAV file
    if [ "$ext_lower" = "wav" ]; then
        print_status "Processing WAV: $filename → ${name_without_ext}.wav"
        
        # Just copy the file with the new name
        if cp "$file" "$output_file" 2>/dev/null; then
            print_success "Renamed/Copied '$filename' → '${name_without_ext}.wav'"
            ((processed_count++))
        else
            print_error "Failed to copy '$filename'"
            ((error_count++))
        fi
    else
        print_status "Converting: $filename → ${name_without_ext}.wav"
        
        # Convert to WAV format
        if ffmpeg -i "$file" \
            -acodec pcm_s${BIT_DEPTH}le \
            -ar $SAMPLE_RATE \
            -ac $CHANNELS \
            "$output_file" \
            -y 2>/dev/null; then
            
            print_success "Converted '$filename' → '${name_without_ext}.wav'"
            ((processed_count++))
        else
            print_error "Failed to convert '$filename'"
            ((error_count++))
        fi
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
    print_status "WAV settings: ${SAMPLE_RATE}Hz, ${BIT_DEPTH}-bit, ${CHANNELS} channel(s)"
    if [ "$RENAME_TO_SNAKE_CASE" = true ]; then
        print_status "Naming: snake_case (lowercase with underscores)"
    fi
fi

echo
print_status "Done!"