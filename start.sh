#!/bin/bash

CONFIG_FILE="./sys_config.dat"
LOG_FILE="./sys_worker.log"
BIN="./sys_worker"

# Fungsi untuk edit config.json
update_config_threads() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "[*] Mengubah max-threads-hint di config.json menjadi $1..."
        jq ".cpu.\"max-threads-hint\" = $1" "$CONFIG_FILE" > config_tmp.json && mv config_tmp.json "$CONFIG_FILE"
    else
        echo "❌ config.json tidak ditemukan di direktori ini!"
        exit 1
    fi
}

echo "==========================================="
echo "        Worker Process Launcher (HIDDEN)   "
echo "==========================================="
echo ""

# Cek jumlah core fisik
TOTAL_CORES=$(nproc)
echo "[*] CPU Detected: $TOTAL_CORES core"

# Pilih jumlah core
echo "Pilih jumlah core yang ingin digunakan:"
echo "1) 4 Core (HugePages 2048 = 4 GB)"
echo "2) 8 Core (HugePages 3072 = 6 GB)"
read -rp "Pilihan kamu (1/2): " pilihan

if [ "$pilihan" == "1" ]; then
    CORES=4
    MASK=0x0f
    HUGEPAGES=2048
    TMUX_NAME="syswrk4"
elif [ "$pilihan" == "2" ]; then
    CORES=8
    MASK=0xff
    HUGEPAGES=3072
    TMUX_NAME="syswrk8"
else
    echo "❌ Pilihan tidak valid. Keluar."
    exit 1
fi

# Reset HugePages
echo ""
echo "[*] Resetting HugePages..."
sudo sysctl -w vm.nr_hugepages=0
sleep 1

echo "[*] Setting HugePages to $HUGEPAGES..."
sudo sysctl -w vm.nr_hugepages=$HUGEPAGES

# Update config.json
update_config_threads "$CORES"

# Jalankan dalam tmux
echo ""
echo "[*] Menjalankan worker di dalam tmux session: $TMUX_NAME"
echo "[*] CMD: sudo nice -n -20 taskset -a $MASK $BIN"

tmux new-session -d -s "$TMUX_NAME" "sudo nice -n -20 taskset -a $MASK $BIN | tee -a $LOG_FILE"

echo ""
echo "✅ Worker berhasil dijalankan di tmux ($TMUX_NAME)."
echo "ℹ️ Gunakan perintah berikut untuk melihat proses:"
echo "   tmux attach -t $TMUX_NAME"
echo "📄 Log output tersimpan di: $LOG_FILE"
