#!/bin/bash

SCRIPT_NAME="nextcloud-aio_auto-update.sh"
SCRIPT_PATH="/root/$SCRIPT_NAME"
LOG_FILE="/var/log/nextcloud_aio_auto-update.log"
PYTHON_SCRIPT="/tmp/get_schedule_time.py"

echo "$(date) ---- Configurando automação Nextcloud AIO ----" | tee -a "$LOG_FILE"

# Criar script Python
cat << 'EOF' > "$PYTHON_SCRIPT"
#!/usr/bin/env python3

import re

while True:
    schedule_time = input("Digite o horário de agendamento (HH:MM): ")
    if re.match(r"^[0-2][0-9]:[0-5][0-9]$", schedule_time):
        confirm = input(f"Confirma o horário de agendamento {schedule_time}? (s/n): ")
        if confirm == "s":
            print(schedule_time)
            break
    else:
        print("Formato inválido. Digite o horário (HH:MM).")
EOF

chmod +x "$PYTHON_SCRIPT"

SCHEDULE_TIME="$("$PYTHON_SCRIPT")"

if [[ -z "$SCHEDULE_TIME" ]]; then
    echo "$(date) [ERRO] Falha ao obter o horário de agendamento." | tee -a "$LOG_FILE"
    exit 1
fi

SCHEDULE_HOUR=$(echo "$SCHEDULE_TIME" | cut -d ':' -f 1)
SCHEDULE_MINUTE=$(echo "$SCHEDULE_TIME" | cut -d ':' -f 2)
CRON_JOB="$SCHEDULE_MINUTE $SCHEDULE_HOUR * * * /root/$SCRIPT_NAME >> $LOG_FILE 2>&1"

# Criar script local
cat << "EOF" > "$SCRIPT_PATH"
#!/bin/bash

LOG_FILE="$LOG_FILE"
echo "\$(date) ---- Iniciando automação Nextcloud AIO ----" | tee -a "\$LOG_FILE"

if ! docker exec --env AUTOMATIC_UPDATES=1 nextcloud-aio-mastercontainer /daily-backup.sh 2>&1; then
    echo "\$(date) [ERRO] Primeira tentativa de atualização falhou." | tee -a "\$LOG_FILE"

    while docker ps --format "{{.Names}}" | grep -q "^nextcloud-aio-watchtower$"; do
        echo "\$(date) Aguardando watchtower parar..." | tee -a "\$LOG_FILE"
        sleep 30
    done

    while ! docker ps --format "{{.Names}}" | grep -q "^nextcloud-aio-mastercontainer$"; do
        echo "\$(date) Aguardando Mastercontainer iniciar..." | tee -a "\$LOG_FILE"
        sleep 30
    done

    if ! docker exec --env AUTOMATIC_UPDATES=1 nextcloud-aio-mastercontainer /daily-backup.sh 2>&1; then
        echo "\$(date) [ERRO] Segunda tentativa de atualização falhou." | tee -a "\$LOG_FILE"
        exit 1
    fi
fi

echo "\$(date) ---- Automação Nextcloud AIO concluída! ----" | tee -a "\$LOG_FILE"
EOF

# Aplicar permissões
chmod +x "$SCRIPT_PATH"
echo "$(date) Script salvo em $SCRIPT_PATH" | tee -a "$LOG_FILE"

# Adicionar cronjob
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
echo "$(date) Agendamento configurado para $SCHEDULE_TIME" | tee -a "$LOG_FILE"

# Execução manual inicial
read -r -p "Deseja executar a atualização agora? (s/n): " RUN_NOW
echo "$(date) Resposta da execução manual: '$RUN_NOW'." | tee -a "$LOG_FILE"
if [[ "$RUN_NOW" == "s" ]]; then
    echo "$(date) Executando atualização manual..." | tee -a "$LOG_FILE"
    "$SCRIPT_PATH"
else
    echo "$(date) Atualização manual ignorada." | tee -a "$LOG_FILE"
fi

echo "$(date) ---- Configuração concluída! ----" | tee -a "$LOG_FILE"
