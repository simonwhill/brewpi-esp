#!/bin/sh
# Build the two flashable images for the pump firmware from an existing PlatformIO build.
#   Usage: scripts/make_pump_images.sh [env] [outdir]
# Requires: `pio run -e <env>` and `pio run -e <env> -t buildfs` already run.
# Produces:
#   <outdir>/<env>_full.bin  - first install: flash at 0x0 (wipes device assignments)
#   <outdir>/<env>_app.bin   - upgrade: flash at the otadata offset (keeps WiFi + assignments)
set -eu
ENV="${1:-esp32_s2_wifi_pump}"
OUT="${2:-bin}"
CSV="4mb_inc_ota.csv"          # board_build.partitions of esp32_s2_wifi
CHIP="esp32s2"
BOOTLOADER_OFFSET=0x1000       # ESP32-S2 second-stage bootloader
PARTTABLE_OFFSET=0x8000        # ESP-IDF default partition-table offset
PKGS="${PLATFORMIO_CORE_DIR:-$HOME/.platformio}/packages"
BUILD="${BUILD_DIR:-.pio/build/$ENV}"   # override with BUILD_DIR if the bins were staged elsewhere

offset() { awk -F, -v n="$1" '$1 ~ "^"n"[[:space:]]*$" {gsub(/[[:space:]]/,"",$4); print $4}' "$CSV"; }
OTADATA=$(offset otadata); APP0=$(offset app0); FS=$(offset spiffs)
for v in OTADATA APP0 FS; do eval "[ -n \"\$$v\" ]" || { echo "missing $v offset in $CSV" >&2; exit 1; }; done

FSBIN="$BUILD/littlefs.bin"; [ -f "$FSBIN" ] || FSBIN="$BUILD/spiffs.bin"
for f in "$BUILD/bootloader.bin" "$BUILD/partitions.bin" "$BUILD/firmware.bin" "$FSBIN" \
         "$PKGS/framework-arduinoespressif32/tools/partitions/boot_app0.bin"; do
  [ -f "$f" ] || { echo "missing $f" >&2; exit 1; }
done

mkdir -p "$OUT"
python3 "$PKGS/tool-esptoolpy/esptool.py" --chip "$CHIP" merge_bin -o "$OUT/${ENV}_full.bin" \
  "$BOOTLOADER_OFFSET" "$BUILD/bootloader.bin" \
  "$PARTTABLE_OFFSET" "$BUILD/partitions.bin" \
  "$OTADATA" "$PKGS/framework-arduinoespressif32/tools/partitions/boot_app0.bin" \
  "$APP0" "$BUILD/firmware.bin" \
  "$FS" "$FSBIN"
# Upgrade image: otadata reset (boot app0 even if an OTA update moved it to app1) + app0.
# Leaves NVS (WiFi) and the filesystem (device assignments) untouched.
python3 "$PKGS/tool-esptoolpy/esptool.py" --chip "$CHIP" merge_bin -o "$OUT/${ENV}_app.bin" \
  --target-offset "$OTADATA" \
  "$OTADATA" "$PKGS/framework-arduinoespressif32/tools/partitions/boot_app0.bin" \
  "$APP0" "$BUILD/firmware.bin"
echo "$OTADATA" > "$OUT/${ENV}_app.offset"
echo "full image: $OUT/${ENV}_full.bin (flash at 0x0)"
echo "app image:  $OUT/${ENV}_app.bin (flash at $OTADATA)"
