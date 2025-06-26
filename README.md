# Audio to HLS Converter

A collection of bash scripts to convert audio files into HLS (HTTP Live Streaming) format for web streaming applications.

## Overview

This repository contains two versions of an audio-to-HLS converter:

1. **`convert_audio_hls.sh`** - Full-featured converter with multiple format support and comprehensive error handling
2. **`convert_audio_hls_simple.sh`** - Lightweight converter focused on WAV files with minimal dependencies

Both scripts use FFmpeg to convert audio files into `.m3u8` playlists with `.ts` segment files, making them suitable for streaming applications.

## Features

### Full-Featured Version (`convert_audio_hls.sh`)
- ✅ **Multiple Format Support**: MP3, WAV, FLAC, M4A, AAC, OGG
- ✅ **Batch Processing**: Convert all supported files in one go
- ✅ **Error Handling**: Comprehensive error checking and reporting
- ✅ **Colored Output**: Easy-to-read status messages
- ✅ **Conversion Statistics**: Summary of successful and failed conversions
- ✅ **Configurable Settings**: Adjustable segment duration and playlist size
- ✅ **File Validation**: Checks for FFmpeg installation and input directory

### Simple Version (`convert_audio_hls_simple.sh`)
- ✅ **WAV Focus**: Optimized for WAV file conversion
- ✅ **Lightweight**: Minimal code with essential functionality
- ✅ **Quick Setup**: No configuration needed
- ✅ **Fast Processing**: Streamlined conversion process

## Prerequisites

- **FFmpeg**: Must be installed and accessible from command line
- **Bash**: Unix/Linux shell environment
- **File System**: Read/write permissions for input and output directories

### Installing FFmpeg

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install ffmpeg
```

**macOS (with Homebrew):**
```bash
brew install ffmpeg
```

**Windows:**
Download from [FFmpeg official website](https://ffmpeg.org/download.html) and add to PATH.

## Installation

1. **Clone the repository:**
```bash
git clone https://github.com/yourusername/audio-to-hls-converter.git
cd audio-to-hls-converter
```

2. **Make scripts executable:**
```bash
chmod +x convert_audio_hls.sh
chmod +x convert_audio_hls_simple.sh
```

3. **Create required directories:**
```bash
mkdir input_folder
mkdir output_folder
```

## Usage

### Step 1: Setup Directories

**Important:** You must create the input and output folders before running the scripts.

```bash
# Create input folder for your audio files
mkdir input_folder

# Create output folder for converted HLS files
mkdir output_folder
```

### Step 2: Add Audio Files

Place your audio files in the `input_folder/` directory:

```
input_folder/
├── song1.mp3
├── song2.wav
├── podcast.flac
└── audio.m4a
```

### Step 3: Run the Converter

**For full-featured conversion:**
```bash
./convert_audio_hls.sh
```

**For simple WAV conversion only:**
```bash
./convert_audio_hls_simple.sh
```

### Step 4: Access Converted Files

After conversion, your output structure will look like:

```
output_folder/
├── song1/
│   ├── song1.m3u8
│   ├── song1_000.ts
│   ├── song1_001.ts
│   └── song1_002.ts
├── song2/
│   ├── song2.m3u8
│   ├── song2_000.ts
│   └── song2_001.ts
└── podcast/
    ├── podcast.m3u8
    ├── podcast_000.ts
    ├── podcast_001.ts
    └── podcast_002.ts
```

## Configuration

### Full-Featured Version Settings

Edit the configuration variables at the top of `convert_audio_hls.sh`:

```bash
# Configuration
INPUT_DIR="input_folder"        # Input directory name
OUTPUT_DIR="output_folder"      # Output directory name
HLS_TIME=10                     # Segment duration in seconds
HLS_LIST_SIZE=0                 # 0 = keeps all segments in playlist
```

### Supported Audio Formats

The full-featured version supports:
- MP3 (`.mp3`)
- WAV (`.wav`)
- FLAC (`.flac`)
- M4A (`.m4a`)
- AAC (`.aac`)
- OGG (`.ogg`)

## HLS Output Format

Each converted audio file generates:

- **`.m3u8` file**: HLS playlist containing segment information
- **`.ts` files**: Audio segments (10 seconds each by default)

### Example .m3u8 Content:
```
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:10.0,
song_000.ts
#EXTINF:10.0,
song_001.ts
#EXTINF:8.5,
song_002.ts
#EXT-X-ENDLIST
```

## Usage in Web Applications

### HTML5 Audio with HLS.js

```html
<script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
<audio id="audio" controls></audio>

<script>
  const audio = document.getElementById('audio');
  const hls = new Hls();
  hls.loadSource('output_folder/song1/song1.m3u8');
  hls.attachMedia(audio);
</script>
```

### Direct HTML5 (Safari/iOS)

```html
<audio controls>
  <source src="output_folder/song1/song1.m3u8" type="application/vnd.apple.mpegurl">
</audio>
```

## Troubleshooting

### Common Issues

**FFmpeg not found:**
```bash
# Check if FFmpeg is installed
ffmpeg -version

# Install if missing (Ubuntu/Debian)
sudo apt install ffmpeg
```

**Permission denied:**
```bash
# Make script executable
chmod +x convert_audio_hls.sh
```

**No files found:**
- Ensure audio files are in the `input_folder/` directory
- Check that file extensions match supported formats
- Verify file permissions

**Conversion fails:**
- Check audio file integrity
- Ensure sufficient disk space
- Verify FFmpeg supports the input format

### Debug Mode

For detailed FFmpeg output, modify the conversion command by removing `2>/dev/null`:

```bash
# In convert_audio_hls.sh, change:
ffmpeg -i "$file" ... 2>/dev/null

# To:
ffmpeg -i "$file" ...
```

## Advanced Usage

### Custom Segment Duration

Modify `HLS_TIME` for different segment lengths:

```bash
HLS_TIME=5   # 5-second segments (more segments, better seeking)
HLS_TIME=30  # 30-second segments (fewer segments, less overhead)
```

### Playlist Size Limit

Control how many segments are kept in the playlist:

```bash
HLS_LIST_SIZE=0   # Keep all segments (default)
HLS_LIST_SIZE=10  # Keep only last 10 segments (rolling window)
```

### Custom Audio Quality

Modify the FFmpeg parameters in the script:

```bash
# Higher quality (256kbps)
-c:a aac -b:a 256k -ar 48000

# Lower quality (64kbps)
-c:a aac -b:a 64k -ar 22050
```

## File Structure

```
audio-to-hls-converter/
├── convert_audio_hls.sh         # Full-featured converter
├── convert_audio_hls_simple.sh  # Simple WAV converter
├── README.md                    # This file
├── input_folder/                # Place your audio files here
│   ├── song1.mp3
│   ├── song2.wav
│   └── ...
└── output_folder/               # Converted HLS files appear here
    ├── song1/
    │   ├── song1.m3u8
    │   └── song1_*.ts
    └── song2/
        ├── song2.m3u8
        └── song2_*.ts
```

## Use Cases

- **Web Audio Streaming**: Stream audio content on websites
- **Podcast Distribution**: Convert podcast episodes for web playback
- **Music Streaming Apps**: Prepare audio files for HLS-based players
- **Educational Content**: Stream lectures and audio lessons
- **Radio Streaming**: Convert radio shows for on-demand playback

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Verify FFmpeg installation and version
3. Ensure proper file permissions
4. Create an issue on GitHub with error details

## Changelog

### v1.0.0
- Initial release
- Full-featured converter with multiple format support
- Simple WAV-focused converter
- Comprehensive error handling and logging
- Configurable segment duration and playlist settings

---

**⚠️ Note**: Make sure to create the `input_folder` and `output_folder` directories before running the scripts. The scripts will not automatically create the input folder, and you need to place your audio files there manually.
