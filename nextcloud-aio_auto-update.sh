#!/bin/bash

SCRIPT_NAME="nextcloud-aio_auto-update.sh"
SCRIPT_PATH="/root/$SCRIPT_NAME"
LOG_FILE="/var/log/nextcloud_aio_auto-update.log"

echo "$(date) ---- Configurando automação Nextcloud AIO ----" | tee -a "$LOG_FILE"

SCHEDULE_TIME=""
while [[ -z "$SCHEDULE_TIME" ]]; do
    read -p "Digite o horário de agendamento (HH:MM): " SCHEDULE_TIME
    if [[ ! "$SCHEDULE_TIME" =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
        echo "Formato inválido. Digite o horário (HH:MM)."
        SCHEDULE_TIME=""
        continue
    fi

    read -p "Confirma o horário de agendamento $SCHEDULE_TIME? (s/n): " CONFIRM
    if [[ "$CONFIRM" != "s" ]]; then
        SCHEDULE_TIME=""
    fi
done

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
read -p "Deseja executar a atualização agora? (s/n): " RUN_NOW
if [[ "$RUN_NOW" == "s" ]]; then
    echo "$(date) Executando atualização manual..." | tee -a "$LOG_FILE"
    "$SCRIPT_PATH"
else
    echo "$(date) Atualização manual ignorada." | tee -a "$LOG_FILE"
fi

echo "$(date) ---- Configuração concluída! ----" | tee -a "$LOG_FILE"
