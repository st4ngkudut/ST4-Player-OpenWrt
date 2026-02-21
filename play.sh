#!/bin/bash
# ==========================================
# ST4 PLAYER - TINKERBOARD ENGINE (AUTO-PLAY FIXED)
# ==========================================

export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
export LC_ALL=C.UTF-8

# --- CONFIG ---
SOCKET="/tmp/mpv_socket"
MODE_FILE="/root/output_mode"
BP_FILE="/root/bp_mode"
LOG_FILE="/root/mpv_error.log"

INPUT_LINK="$1"
START_TIME="${2:-0}"

# 1. BERSIHKAN SESI LAMA
# Matikan MPV sebelumnya agar tidak tumpang tindih
killall -9 mpv > /dev/null 2>&1 || true
rm -f "$SOCKET"
sleep 0.5 

# 2. DETEKSI MPV
MPV_BIN=$(which mpv)
if [ -z "$MPV_BIN" ]; then MPV_BIN="/usr/bin/mpv"; fi

# 3. DETEKSI OUTPUT
# Default: Tinkerboard Jack (Card 1, Device 2)
AUDIO_DEVICE="alsa/plughw:0,0"

if [ -f "$MODE_FILE" ]; then
    READ_MODE=$(cat "$MODE_FILE")
    if [[ "$READ_MODE" != "" ]]; then
        AUDIO_DEVICE="$READ_MODE"
    fi
    
    # OVERRIDE LOGIC (Fix Device)
    if [[ "$READ_MODE" == *"plughw"* ]]; then
        if [[ "$READ_MODE" == *"hdmi"* || "$READ_MODE" == *"2,0"* ]]; then
             AUDIO_DEVICE="alsa/plughw:2,0"
        else
             AUDIO_DEVICE="alsa/plughw:0,0"
        fi
    fi
fi

# 4. CONFIG AUDIO EXTRA
EXTRA_ARGS=""

if [[ "$AUDIO_DEVICE" == *"bluealsa"* ]]; then
    # Bluetooth: Wajib Resample ke 44.1/48k biar stabil
    EXTRA_ARGS="--ao=alsa --audio-format=s16 --audio-samplerate=44100 --audio-buffer=0.5"
else
    # Kabel (Jack/HDMI)
    IS_BP="0"
    if [ -f "$BP_FILE" ]; then IS_BP=$(cat "$BP_FILE" | tr -d '[:space:]'); fi

    if [ "$IS_BP" == "1" ]; then
        # Bit Perfect: Matikan resample software
        EXTRA_ARGS="--ao=alsa --no-audio-resample --audio-buffer=0.2"
    else
        # Normal Mode
        EXTRA_ARGS="--ao=alsa"
    fi
fi

# 5. CEK SUMBER (BUFFERING)
if [ -f "$INPUT_LINK" ]; then
    # File Lokal: Buffer kecil biar seek cepat
    CACHE_OPTS="--cache=yes --demuxer-max-bytes=5M"
    YTDL_OPTS=""
else
    # Streaming (Youtube): Buffer besar biar tidak putus-putus
    CACHE_OPTS="--cache=yes --demuxer-max-bytes=20M --demuxer-max-back-bytes=10M" 
    YTDL_OPTS="--ytdl-format=bestaudio/best --ytdl-raw-options=ignore-errors=,no-check-certificate="
fi

# 6. GAS PLAY
# Perubahan PENTING: --keep-open=yes (Agar Auto Play jalan)
nohup "$MPV_BIN" "$INPUT_LINK" \
    --start="$START_TIME" \
    --input-ipc-server="$SOCKET" \
    --no-video \
    --force-window=no \
    --no-terminal \
    --volume=30 \
    --audio-device="$AUDIO_DEVICE" \
    --keep-open=yes \
    --idle=yes \
    --msg-level=all=error \
    $CACHE_OPTS \
    $YTDL_OPTS \
    $EXTRA_ARGS \
    >> "$LOG_FILE" 2>&1 &

disown
