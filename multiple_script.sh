#!/bin/bash

# Configuration
INPUT_DIR="input_folder"
OUTPUT_DIR="output_folder"
HLS_TIME=10          # Segment duration in seconds
HLS_LIST_SIZE=0      # 0 means keep all segments in playlist

# Audio quality presets
# Options: "high" (256k), "medium" (128k), "low" (64k), "source" (match original)
QUALITY_PRESET="medium"

# Advanced: Set custom bitrate (overrides preset if set)
# Example: CUSTOM_BITRATE="192k"
CUSTOM_BITRATE=""

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

# Function to get bitrate based on preset
get_bitrate() {
    if [ -n "$CUSTOM_BITRATE" ]; then
        echo "$CUSTOM_BITRATE"
        return
    fi
    
    case $QUALITY_PRESET in
        "high")
            echo "256k"
            ;;
        "medium")
            echo "128k"
            ;;
        "low")
            echo "64k"
            ;;
        "source")
            echo ""  # Empty means copy audio without re-encoding
            ;;
        *)
            echo "128k"
            ;;
    esac
}

# Function to get source file bitrate
get_source_bitrate() {
    local file="$1"
    ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null
}

# Function to get source file size
get_file_size() {
    stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null
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

# Display compression settings
TARGET_BITRATE=$(get_bitrate)
if [ -z "$TARGET_BITRATE" ]; then
    print_status "Quality preset: $QUALITY_PRESET (source quality - no compression)"
else
    print_status "Quality preset: $QUALITY_PRESET (target bitrate: $TARGET_BITRATE)"
fi

# Counter for processed files
processed_count=0
error_count=0
total_original_size=0
total_output_size=0

# Function to convert a single file
convert_file() {
    local file="$1"
    local filename=$(basename "$file")
    local name_without_ext="${filename%.*}"
    
    # Get original file size and bitrate
    local original_size=$(get_file_size "$file")
    local source_bitrate=$(get_source_bitrate "$file")
    local source_bitrate_k=""
    if [ -n "$source_bitrate" ]; then
        source_bitrate_k=$((source_bitrate / 1000))
    fi
    
    # Create a subdirectory for each file in the output folder
    local subfolder="$OUTPUT_DIR/$name_without_ext"
    mkdir -p "$subfolder"
    
    # Define output paths for .m3u8 file in the subdirectory
    local m3u8output="$subfolder/${name_without_ext}.m3u8"
    
    print_status "Converting: $filename"
    if [ -n "$source_bitrate_k" ]; then
        print_status "  Source: ${source_bitrate_k}k bitrate, $(numfmt --to=iec-i --suffix=B $original_size 2>/dev/null || echo "$original_size bytes")"
    fi
    
    # Prepare ffmpeg command based on quality preset
    local target_bitrate=$(get_bitrate)
    local ffmpeg_cmd=(ffmpeg -i "$file")
    
    if [ -z "$target_bitrate" ]; then
        # Source quality: copy audio without re-encoding
        ffmpeg_cmd+=(-c:a copy)
        print_status "  Using source quality (no compression)"
    else
        # Compress with specified bitrate
        ffmpeg_cmd+=(
            -c:a aac
            -b:a "$target_bitrate"
            -ar 44100
        )
        print_status "  Compressing to $target_bitrate"
    fi
    
    # Add HLS parameters
    ffmpeg_cmd+=(
        -start_number 0
        -hls_time "$HLS_TIME"
        -hls_list_size "$HLS_LIST_SIZE"
        -hls_segment_filename "$subfolder/${name_without_ext}_%03d.ts"
        -f hls "$m3u8output"
        -y
    )
    
    # Convert to HLS
    if "${ffmpeg_cmd[@]}" 2>/dev/null; then
        # Calculate output size (sum of all .ts segments + .m3u8)
        local output_size=0
        for ts_file in "$subfolder"/*.ts; do
            if [ -f "$ts_file" ]; then
                output_size=$((output_size + $(get_file_size "$ts_file")))
            fi
        done
        output_size=$((output_size + $(get_file_size "$m3u8output")))
        
        # Calculate compression ratio
        if [ $original_size -gt 0 ]; then
            local ratio=$(awk "BEGIN {printf \"%.1f\", ($original_size - $output_size) / $original_size * 100}")
            local output_size_human=$(numfmt --to=iec-i --suffix=B $output_size 2>/dev/null || echo "$output_size bytes")
            
            if (( $(echo "$ratio > 0" | bc -l 2>/dev/null || [ $original_size -gt $output_size ] && echo 1 || echo 0) )); then
                print_success "Converted '$filename' → '$subfolder/' (${ratio}% smaller, $output_size_human)"
            else
                print_success "Converted '$filename' → '$subfolder/' ($output_size_human)"
            fi
            
            total_original_size=$((total_original_size + original_size))
            total_output_size=$((total_output_size + output_size))
        else
            print_success "Converted '$filename' → '$subfolder/'"
        fi
        
        ((processed_count++))
    else
        print_error "Failed to convert '$filename'"
        ((error_count++))
    fi
}

# Process all supported audio formats
found_files=false

for format in "${SUPPORTED_FORMATS[@]}"; do
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
    
    # Show total size savings
    if [ $total_original_size -gt 0 ]; then
        local total_saved=$((total_original_size - total_output_size))
        local total_ratio=$(awk "BEGIN {printf \"%.1f\", $total_saved / $total_original_size * 100}")
        local orig_human=$(numfmt --to=iec-i --suffix=B $total_original_size 2>/dev/null || echo "$total_original_size bytes")
        local output_human=$(numfmt --to=iec-i --suffix=B $total_output_size 2>/dev/null || echo "$total_output_size bytes")
        local saved_human=$(numfmt --to=iec-i --suffix=B $total_saved 2>/dev/null || echo "$total_saved bytes")
        
        echo
        print_status "Total original size: $orig_human"
        print_status "Total output size: $output_human"
        if (( $(echo "$total_ratio > 0" | bc -l 2>/dev/null || [ $total_saved -gt 0 ] && echo 1 || echo 0) )); then
            print_success "Total saved: $saved_human (${total_ratio}% compression)"
        fi
    fi
    
    print_status "Output directory: $OUTPUT_DIR"
fi

echo
print_status "Done!"