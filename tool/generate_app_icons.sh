#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_icon=${1:-"$repo_root/assets/branding/app_icon_master.png"}

if ! command -v magick >/dev/null 2>&1; then
  printf '%s\n' 'ImageMagick (magick) is required.' >&2
  exit 1
fi
if [[ ! -f "$source_icon" ]]; then
  printf 'Icon source not found: %s\n' "$source_icon" >&2
  exit 1
fi

dimensions=$(magick identify -format '%w %h' "$source_icon")
if [[ "$dimensions" != "1024 1024" ]]; then
  printf 'Master icon must be exactly 1024x1024; got %s.\n' "$dimensions" >&2
  exit 1
fi

android_res="$repo_root/android/app/src/main/res"
ios_icons="$repo_root/ios/Runner/Assets.xcassets/AppIcon.appiconset"

legacy_sizes=(48 72 96 144 192)
adaptive_sizes=(108 162 216 324 432)
densities=(mdpi hdpi xhdpi xxhdpi xxxhdpi)

for index in "${!densities[@]}"; do
  density=${densities[$index]}
  legacy=${legacy_sizes[$index]}
  adaptive=${adaptive_sizes[$index]}
  mipmap_dir="$android_res/mipmap-$density"
  drawable_dir="$android_res/drawable-$density"
  mkdir -p "$mipmap_dir" "$drawable_dir"

  magick "$source_icon" -filter Lanczos -resize "${legacy}x${legacy}!" \
    -strip -colorspace sRGB "PNG24:$mipmap_dir/ic_launcher.png"

  # Round fallback for launchers before adaptive icons. Adaptive launchers use
  # the XML resources below and apply their own selected mask.
  magick "$source_icon" -filter Lanczos -resize "${legacy}x${legacy}!" \
    \( -size "${legacy}x${legacy}" xc:none -fill white \
       -draw "circle $((legacy / 2)),$((legacy / 2)) $((legacy / 2)),0" \) \
    -alpha off -compose CopyOpacity -composite -strip \
    "PNG32:$mipmap_dir/ic_launcher_round.png"

  magick "$source_icon" -filter Lanczos -resize "${adaptive}x${adaptive}!" \
    -strip -colorspace sRGB "PNG24:$drawable_dir/ic_launcher_foreground.png"

  # Android 13 themed icon: retain the bright M and golden smile/cheeks as a
  # single-color alpha mask while dropping the blue/violet tile.
  magick "$source_icon" -filter Lanczos -resize "${adaptive}x${adaptive}!" \
    -alpha off \
    -fx "(((i/w>0.22 && i/w<0.74 && j/h>0.23 && j/h<0.62) && (r>0.68 && g>0.58 && b>0.68)) || ((i/w>0.18 && i/w<0.82 && j/h>0.50 && j/h<0.78) && (r>0.72 && g>0.34 && b<0.48))) ? 1 : 0" \
    -morphology Close Disk:2 \
    -write mpr:mask +delete \
    -size "${adaptive}x${adaptive}" xc:white mpr:mask \
    -alpha off -compose CopyOpacity -composite -strip \
    "PNG32:$drawable_dir/ic_launcher_monochrome.png"
done

resize_ios() {
  local pixels=$1
  local filename=$2
  magick "$source_icon" -filter Lanczos -resize "${pixels}x${pixels}!" \
    -alpha off -strip -colorspace sRGB "PNG24:$ios_icons/$filename"
}

resize_ios 40 Icon-App-20x20@2x.png
resize_ios 60 Icon-App-20x20@3x.png
resize_ios 29 Icon-App-29x29@1x.png
resize_ios 58 Icon-App-29x29@2x.png
resize_ios 87 Icon-App-29x29@3x.png
resize_ios 80 Icon-App-40x40@2x.png
resize_ios 120 Icon-App-40x40@3x.png
resize_ios 120 Icon-App-60x60@2x.png
resize_ios 180 Icon-App-60x60@3x.png
resize_ios 20 Icon-App-20x20@1x.png
resize_ios 40 Icon-App-40x40@1x.png
resize_ios 76 Icon-App-76x76@1x.png
resize_ios 152 Icon-App-76x76@2x.png
resize_ios 167 Icon-App-83.5x83.5@2x.png
resize_ios 1024 Icon-App-1024x1024@1x.png

printf '%s\n' 'Generated Android legacy/adaptive/themed icons and all iOS AppIcon sizes.'
