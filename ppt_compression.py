#!/usr/bin/env python3
"""
PowerPoint Aggressive Compression Script
Compresses PPTX files significantly to reduce file size below target
"""

import os
import sys
import zipfile
import shutil
from pathlib import Path
import argparse
from PIL import Image
from io import BytesIO
import time


def optimize_image_aggressive(image_data, quality=60, max_dimension=1280):
    """
    Aggressively optimize image for maximum compression

    Args:
        image_data: Binary image data
        quality: JPEG quality (1-100, lower = more compression)
        max_dimension: Maximum width/height in pixels

    Returns:
        Optimized image data
    """
    try:
        img = Image.open(BytesIO(image_data))

        # Convert to RGB if necessary
        if img.mode in ("RGBA", "LA", "P"):
            background = Image.new("RGB", img.size, (255, 255, 255))
            if img.mode == "P":
                img = img.convert("RGBA")
            if img.mode in ("RGBA", "LA"):
                background.paste(img, mask=img.split()[-1])
            else:
                background.paste(img)
            img = background
        elif img.mode != "RGB":
            img = img.convert("RGB")

        # Aggressive resize if image is large
        if max(img.size) > max_dimension:
            ratio = max_dimension / max(img.size)
            new_size = tuple(int(dim * ratio) for dim in img.size)
            img = img.resize(new_size, Image.Resampling.LANCZOS)

        # Additional downscaling for very large images
        # This ensures even HD images get compressed
        while max(img.size) > max_dimension * 1.2:
            new_size = tuple(int(dim * 0.8) for dim in img.size)
            img = img.resize(new_size, Image.Resampling.LANCZOS)

        # Save with aggressive compression
        output = BytesIO()
        img.save(
            output, format="JPEG", quality=quality, optimize=True, progressive=True
        )

        return output.getvalue()

    except Exception as e:
        print(f"    Warning: Could not optimize image: {e}")
        return image_data


def compress_pptx(
    input_path, output_path, quality=60, max_dimension=1280, target_size_mb=None
):
    """
    Compress PPTX file aggressively

    Args:
        input_path: Path to input PPTX file
        output_path: Path to output compressed PPTX file
        quality: Image quality (1-100, recommend 50-70 for aggressive compression)
        max_dimension: Maximum image dimension in pixels (recommend 1024-1280)
        target_size_mb: Target size in MB (will try multiple passes if needed)

    Returns:
        Tuple of (success, original_size, compressed_size, compression_ratio)
    """
    temp_dir = None

    # Try different quality levels if target size is specified
    quality_levels = [quality]
    if target_size_mb:
        quality_levels = [quality, quality - 10, quality - 20, quality - 30]

    for attempt_quality in quality_levels:
        if attempt_quality < 30:  # Don't go below 30 quality
            attempt_quality = 30

        try:
            # Create temporary directory with unique name
            temp_dir = Path(f"temp_pptx_{int(time.time() * 1000)}")
            if temp_dir.exists():
                shutil.rmtree(temp_dir)
            temp_dir.mkdir(exist_ok=True)

            # Extract PPTX (it's a ZIP file)
            with zipfile.ZipFile(input_path, "r") as zip_ref:
                zip_ref.extractall(temp_dir)

            # Process images in media folder
            media_folder = temp_dir / "ppt" / "media"
            if media_folder.exists():
                image_count = 0
                total_original_size = 0
                total_compressed_size = 0

                for image_file in media_folder.glob("*"):
                    if image_file.suffix.lower() in [
                        ".png",
                        ".jpg",
                        ".jpeg",
                        ".bmp",
                        ".gif",
                        ".tiff",
                        ".tif",
                    ]:
                        try:
                            original_size = image_file.stat().st_size
                            total_original_size += original_size

                            with open(image_file, "rb") as f:
                                image_data = f.read()

                            optimized_data = optimize_image_aggressive(
                                image_data, attempt_quality, max_dimension
                            )

                            # Save optimized image with .jpg extension
                            new_path = image_file.with_suffix(".jpg")
                            with open(new_path, "wb") as f:
                                f.write(optimized_data)

                            total_compressed_size += len(optimized_data)

                            # Remove original if different format
                            if new_path != image_file:
                                image_file.unlink()

                            image_count += 1
                        except Exception as e:
                            print(
                                f"    Warning: Could not process {image_file.name}: {e}"
                            )

                if image_count > 0:
                    img_compression = (
                        (1 - total_compressed_size / total_original_size) * 100
                        if total_original_size > 0
                        else 0
                    )
                    print(
                        f"    Optimized {image_count} images (quality: {attempt_quality}, {img_compression:.1f}% reduction)"
                    )

            # Remove unnecessary files
            unnecessary_files = [
                temp_dir / "docProps" / "thumbnail.jpeg",
                temp_dir / "docProps" / "thumbnail.jpg",
            ]
            for file_path in unnecessary_files:
                if file_path.exists():
                    try:
                        file_path.unlink()
                    except:
                        pass

            # Create compressed PPTX with maximum compression
            with zipfile.ZipFile(
                output_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9
            ) as zipf:
                for root, dirs, files in os.walk(temp_dir):
                    for file in files:
                        file_path = Path(root) / file
                        arcname = file_path.relative_to(temp_dir)
                        zipf.write(file_path, arcname)

            # Clean up temporary directory
            shutil.rmtree(temp_dir)

            # Calculate compression stats
            original_size = os.path.getsize(input_path)
            compressed_size = os.path.getsize(output_path)
            compression_ratio = (1 - compressed_size / original_size) * 100

            # Check if we met the target
            if target_size_mb:
                compressed_mb = compressed_size / (1024 * 1024)
                if (
                    compressed_mb <= target_size_mb
                    or attempt_quality == quality_levels[-1]
                ):
                    return True, original_size, compressed_size, compression_ratio
                else:
                    print(
                        f"    Size {compressed_mb:.1f}MB exceeds target {target_size_mb}MB, trying lower quality..."
                    )
                    if output_path.exists():
                        output_path.unlink()
                    continue
            else:
                return True, original_size, compressed_size, compression_ratio

        except Exception as e:
            print(f"    Error during compression: {e}")
            # Clean up on error
            if temp_dir and temp_dir.exists():
                try:
                    shutil.rmtree(temp_dir)
                except:
                    pass
            if attempt_quality == quality_levels[-1]:
                return False, 0, 0, 0

    return False, 0, 0, 0


def format_size(size_bytes):
    """Convert bytes to human-readable format"""
    for unit in ["B", "KB", "MB", "GB"]:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} TB"


def main():
    parser = argparse.ArgumentParser(
        description="Aggressively compress PowerPoint files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Maximum compression (quality 50)
  python compress_pptx.py --aggressive
  
  # Compress to under 100MB target
  python compress_pptx.py --target 100
  
  # Custom quality (50-70 recommended for aggressive compression)
  python compress_pptx.py -q 55
  
  # Very aggressive (quality 40, small images)
  python compress_pptx.py -q 40 -m 1024
        """,
    )

    parser.add_argument(
        "--input-folder",
        default="input",
        help="Input folder containing PPTX files (default: input)",
    )
    parser.add_argument(
        "--output-folder",
        default="output",
        help="Output folder for compressed files (default: output)",
    )
    parser.add_argument(
        "-q",
        "--quality",
        type=int,
        default=60,
        help="Image quality (1-100, default: 60 for aggressive compression)",
    )
    parser.add_argument(
        "-m",
        "--max-dimension",
        type=int,
        default=1280,
        help="Maximum image dimension in pixels (default: 1280)",
    )
    parser.add_argument(
        "--aggressive",
        action="store_true",
        help="Use most aggressive compression (quality 50, dimension 1024)",
    )
    parser.add_argument(
        "--target",
        type=int,
        help="Target file size in MB (will try multiple compression levels)",
    )

    args = parser.parse_args()

    # Apply aggressive preset
    if args.aggressive:
        args.quality = 50
        args.max_dimension = 1024
        print("Using aggressive compression mode (quality: 50, max dimension: 1024px)")

    # Validate quality parameter
    if not 1 <= args.quality <= 100:
        print("Error: Quality must be between 1 and 100")
        sys.exit(1)

    # Setup folders
    input_folder = Path(args.input_folder)
    output_folder = Path(args.output_folder)

    # Create input folder if it doesn't exist
    if not input_folder.exists():
        input_folder.mkdir(parents=True, exist_ok=True)
        print(f"Created input folder: {input_folder}")
        print(
            f"Please place your PPTX files in the '{input_folder}' folder and run again."
        )
        sys.exit(0)

    # Create output folder if it doesn't exist
    output_folder.mkdir(parents=True, exist_ok=True)

    # Find all PPTX files
    pptx_files = list(input_folder.glob("*.pptx")) + list(input_folder.glob("*.PPTX"))

    if not pptx_files:
        print(f"No PowerPoint files found in '{input_folder}' folder")
        print(
            f"Please place your .pptx files in the '{input_folder}' folder and run again."
        )
        sys.exit(1)

    # Display settings
    print("=" * 70)
    print("PowerPoint AGGRESSIVE Compression Tool")
    print("=" * 70)
    print(f"Input folder:  {input_folder.absolute()}")
    print(f"Output folder: {output_folder.absolute()}")
    print(f"Quality:       {args.quality}/100")
    print(f"Max dimension: {args.max_dimension}px")
    if args.target:
        print(f"Target size:   {args.target}MB per file")
    print(f"Files found:   {len(pptx_files)}")
    print("=" * 70)
    print()

    # Process files
    total_original = 0
    total_compressed = 0
    successful = 0
    failed = 0

    for i, pptx_file in enumerate(pptx_files, 1):
        output_file = output_folder / pptx_file.name

        original_size = os.path.getsize(pptx_file)
        original_mb = original_size / (1024 * 1024)

        print(
            f"[{i}/{len(pptx_files)}] Processing: {pptx_file.name} ({format_size(original_size)})"
        )

        success, orig_size, comp_size, ratio = compress_pptx(
            pptx_file,
            output_file,
            quality=args.quality,
            max_dimension=args.max_dimension,
            target_size_mb=args.target,
        )

        if success:
            compressed_mb = comp_size / (1024 * 1024)
            print(f"    ✓ Original:    {format_size(orig_size)} ({original_mb:.1f} MB)")
            print(
                f"    ✓ Compressed:  {format_size(comp_size)} ({compressed_mb:.1f} MB)"
            )
            print(
                f"    ✓ Saved:       {format_size(orig_size - comp_size)} ({ratio:.1f}%)"
            )

            if args.target and compressed_mb > args.target:
                print(f"    ⚠ Warning: Still above {args.target}MB target")

            print(f"    ✓ Output:      {output_file.name}")
            total_original += orig_size
            total_compressed += comp_size
            successful += 1
        else:
            print(f"    ✗ Failed to compress")
            failed += 1

        print()

    # Summary
    print("=" * 70)
    print("Compression Summary")
    print("=" * 70)
    print(f"Total files processed:  {len(pptx_files)}")
    print(f"Successfully compressed: {successful}")
    print(f"Failed:                 {failed}")

    if successful > 0:
        print()
        print(
            f"Total original size:    {format_size(total_original)} ({total_original/(1024*1024):.1f} MB)"
        )
        print(
            f"Total compressed size:  {format_size(total_compressed)} ({total_compressed/(1024*1024):.1f} MB)"
        )
        print(
            f"Total space saved:      {format_size(total_original - total_compressed)}"
        )
        print(
            f"Average compression:    {(1 - total_compressed/total_original)*100:.1f}%"
        )

    print("=" * 70)
    print(f"\nCompressed files saved to: {output_folder.absolute()}")

    if args.target:
        print(f"\nNote: If files are still above {args.target}MB target, try:")
        print(f"  - Lower quality: --quality 40")
        print(f"  - Smaller images: --max-dimension 1024")
        print(f"  - Or combine both: --aggressive")


if __name__ == "__main__":
    main()
