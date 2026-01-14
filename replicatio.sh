#!/bin/bash
set -euo pipefail

#################################################
# GLOBAL PATH
#################################################
WORKDIR="/home/repl-job"
CONFIG="$WORKDIR/config.env"
MASTER_STATUS="$WORKDIR/master.status"
DUMPDIR="$WORKDIR/dumps"
LOGDIR="$WORKDIR/logs"

#################################################
# LOAD CONFIG
#################################################
load_config() {
  if [ ! -f "$CONFIG" ]; then
    echo "❌ config.env tidak ditemukan"
    echo "👉 Jalankan menu INIT terlebih dahulu"
    exit 1
  fi
  source "$CONFIG"
}

#################################################
# ROLE DETECTION
#################################################
detect_role() {
  if mysql -N -e "SHOW SLAVE STATUS" | grep -q .; then
    echo "SLAVE"
  else
    echo "MASTER"
  fi
}

ensure_master() {
  if [ "$(detect_role)" != "MASTER" ]; then
    echo "❌ ERROR: Script MASTER dijalankan di SLAVE"
    exit 1
  fi
}

ensure_slave() {
  if [ "$(detect_role)" != "SLAVE" ]; then
    echo "❌ ERROR: Script SLAVE dijalankan di MASTER"
    exit 1
  fi
}

#################################################
# INIT MODE
#################################################
init_mode() {
  clear
  echo "======================================"
  echo " INIT - MariaDB Replication Tool"
  echo "======================================"
  echo

  read -p "Database name             : " DB_NAME
  read -p "MASTER IP                 : " MASTER_IP
  read -p "MASTER MySQL port [3306]  : " MASTER_PORT
  MASTER_PORT=${MASTER_PORT:-3306}

  read -p "SLAVE IP                  : " SLAVE_IP
  read -p "SLAVE SSH port [22]       : " SLAVE_SSH_PORT
  SLAVE_SSH_PORT=${SLAVE_SSH_PORT:-22}

  read -p "SLAVE SSH user [root]     : " SLAVE_SSH_USER
  SLAVE_SSH_USER=${SLAVE_SSH_USER:-root}

  read -p "Replication user          : " REPL_USER

  echo
  echo "[INIT] Membuat directory kerja..."
  mkdir -p "$DUMPDIR" "$LOGDIR"

  cat > "$CONFIG" <<EOF
MASTER_IP=$MASTER_IP
MASTER_PORT=$MASTER_PORT
SLAVE_IP=$SLAVE_IP
SLAVE_SSH_PORT=$SLAVE_SSH_PORT
SLAVE_SSH_USER=$SLAVE_SSH_USER
DB_NAME=$DB_NAME
REPL_USER=$REPL_USER
WORKDIR=$WORKDIR
DUMPDIR=$DUMPDIR
LOGDIR=$LOGDIR
EOF

  echo "[INIT] Ambil MASTER binlog position..."
  read MASTER_LOG_FILE MASTER_LOG_POS <<<$(mysql -N -e "SHOW MASTER STATUS" | awk '{print $1,$2}')

  cat > "$MASTER_STATUS" <<EOF
MASTER_LOG_FILE=$MASTER_LOG_FILE
MASTER_LOG_POS=$MASTER_LOG_POS
CREATED_AT=$(date '+%F %T')
EOF

  echo
  echo "✅ INIT SELESAI"
  echo "📂 $WORKDIR"
  echo "📄 config.env"
  echo "📄 master.status"
  echo
  read -p "Tekan ENTER untuk kembali ke menu..."
}

#################################################
# MASTER : DUMP + COPY + TRIGGER
#################################################
master_dump_and_trigger() {
  load_config
  ensure_master

  TS=$(date +%Y%m%d%H%M%S)
  DUMP_FILE="$DUMPDIR/${DB_NAME}-${TS}.sql.gz"

  echo "[MASTER] Dump database..."
  mysqldump --single-transaction --routines --events \
    --master-data=2 \
    --databases "$DB_NAME" | gzip -9 > "$DUMP_FILE"

  echo "[MASTER] Copy file ke SLAVE..."
  ssh -p "$SLAVE_SSH_PORT" "$SLAVE_SSH_USER@$SLAVE_IP" \
    "mkdir -p $DUMPDIR $LOGDIR"

  scp -P "$SLAVE_SSH_PORT" "$DUMP_FILE" \
    "$SLAVE_SSH_USER@$SLAVE_IP:$DUMPDIR/"

  scp -P "$SLAVE_SSH_PORT" "$0" \
    "$SLAVE_SSH_USER@$SLAVE_IP:$WORKDIR/replication-tool.sh"

  ssh -p "$SLAVE_SSH_PORT" "$SLAVE_SSH_USER@$SLAVE_IP" \
    "chmod +x $WORKDIR/replication-tool.sh"

  SESSION="repl_import_$TS"

  echo "[MASTER] Trigger SLAVE via screen ($SESSION)..."
  ssh -p "$SLAVE_SSH_PORT" "$SLAVE_SSH_USER@$SLAVE_IP" <<EOF
screen -dmS $SESSION bash -c '
cd $WORKDIR &&
./replication-tool.sh --slave >> $LOGDIR/import-$TS.log 2>&1
'
EOF

  echo
  echo "✅ MASTER selesai"
  echo "➡ Monitoring (opsional):"
  echo "ssh -p $SLAVE_SSH_PORT $SLAVE_SSH_USER@$SLAVE_IP screen -r $SESSION"
  echo
}

#################################################
# SLAVE : IMPORT + REPLICATION
#################################################
slave_import() {
  load_config
  ensure_slave
  source "$MASTER_STATUS"

  LATEST_DUMP=$(ls -t $DUMPDIR/${DB_NAME}-*.sql.gz | head -1)

  if [ ! -f "$LATEST_DUMP" ]; then
    echo "❌ Dump tidak ditemukan"
    exit 1
  fi

  echo "[SLAVE] Stop replication..."
  mysql -e "STOP SLAVE; RESET SLAVE;"

  BACKUP_DB="${DB_NAME}_backup_$(date +%s)"
  mysql -e "RENAME DATABASE \`$DB_NAME\` TO \`$BACKUP_DB\`;" 2>/dev/null || true
  mysql -e "CREATE DATABASE \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4;"

  echo "[SLAVE] Import database (progress jika pv tersedia)..."

  if command -v pv >/dev/null 2>&1; then
    pv "$LATEST_DUMP" | gunzip | mysql
  else
    gunzip -c "$LATEST_DUMP" | mysql
  fi

  echo "[SLAVE] Setup replication..."
  mysql -e "
CHANGE MASTER TO
  MASTER_HOST='$MASTER_IP',
  MASTER_PORT=$MASTER_PORT,
  MASTER_USER='$REPL_USER',
  MASTER_LOG_FILE='$MASTER_LOG_FILE',
  MASTER_LOG_POS=$MASTER_LOG_POS;
START SLAVE;
"

  echo
  echo "✅ SLAVE selesai"
  mysql -e "SHOW SLAVE STATUS\G" | egrep "Running|Behind|Last_Error"
}

#################################################
# DOCUMENTATION
#################################################
show_documentation() {
  clear
  cat <<'EOF'
====================================================
 DOKUMENTASI - MariaDB Replication Tool (1 File)
====================================================

⚠️ WAJIB:
----------------------------------------------------
SEBELUM MODE APAPUN,
JALANKAN:

  1) INIT : Dokumentasi & setup config

Tanpa INIT, semua mode lain akan GAGAL.


STRUKTUR DIRECTORY
----------------------------------------------------
/home/repl-job/
 ├─ config.env        → konfigurasi IP, port, db
 ├─ master.status     → binlog position master
 ├─ dumps/            → file dump database
 ├─ logs/             → log import slave
 └─ replication-tool.sh


CARA PAKAI (REAL LIFE)
----------------------------------------------------
1️⃣ INIT (sekali saja)
   ./replication-tool.sh
   pilih: 1

2️⃣ DUMP & TRIGGER (di MASTER)
   ./replication-tool.sh
   pilih: 2

3️⃣ MONITORING (opsional, di SLAVE)
   screen -ls
   screen -r repl_import_xxx
   tail -f /home/repl-job/logs/import-*.log

4️⃣ CEK REPLIKASI (di SLAVE)
   mysql -e "SHOW SLAVE STATUS\G"


ATURAN KEAMANAN
----------------------------------------------------
✔ MASTER tidak import
✔ SLAVE tidak dump
✔ Import via screen
✔ SSH putus aman
✔ Ada progress bar (pv)

====================================================
Tekan ENTER untuk kembali ke menu...
EOF
  read
}

#################################################
# NON INTERACTIVE SLAVE MODE
#################################################
if [ "${1:-}" = "--slave" ]; then
  slave_import
  exit 0
fi

#################################################
# MENU
#################################################
while true; do
  echo "===================================="
  echo " MariaDB Replication Tool"
  echo "===================================="
  echo "Detected role: $(detect_role)"
  echo
  echo "1) INIT        : Dokumentasi & setup config"
  echo "2) MASTER      : Dump + copy + trigger SLAVE"
  echo "3) CHECK       : Cek role server"
  echo "4) EXIT"
  echo "5) DOKUMENTASI : Cara pakai & penjelasan file"
  read -p "Pilih opsi: " OPT

  case "$OPT" in
    1) init_mode ;;
    2) master_dump_and_trigger ;;
    3) detect_role ;;
    4) exit 0 ;;
    5) show_documentation ;;
    *) echo "❌ Opsi tidak valid" ;;
  esac
done
