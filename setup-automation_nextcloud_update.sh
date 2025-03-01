#!/bin/bash

LOG_FILE="/var/log/nextcloud_aio_automation.log"
SCRIPT_PATH="/root/nextcloud_aio_automation.sh"
CRON_JOB="0 4 * * * /root/nextcloud_aio_automation.sh >> /var/log/nextcloud_aio_automation.log 2>&1"

echo "$(date) ---- Configurando automação Nextcloud AIO ----" | tee -a "$LOG_FILE"

# Criar uma cópia local do script
cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

LOG_FILE="/var/log/nextcloud_aio_automation.log"
echo "$(date) ---- Iniciando automação Nextcloud AIO ----" | tee -a "$LOG_FILE"

# Run container update once
if ! docker exec --env AUTOMATIC_UPDATES=1 nextcloud-aio-mastercontainer /daily-backup.sh 2>&1; then
    echo "$(date) [ERRO] Primeira tentativa de atualização falhou." | tee -a "$LOG_FILE"

    while docker ps --format "{{.Names}}" | grep -q "^nextcloud-aio-watchtower$"; do
        echo "$(date) Aguardando watchtower parar..." | tee -a "$LOG_FILE"
        sleep 30
    done

    while ! docker ps --format "{{.Names}}" | grep -q "^nextcloud-aio-mastercontainer$"; do
        echo "$(date) Aguardando Mastercontainer iniciar..." | tee -a "$LOG_FILE"
        sleep 30
    done

    # Run container update another time to make sure that all containers are updated correctly.
    if ! docker exec --env AUTOMATIC_UPDATES=1 nextcloud-aio-mastercontainer /daily-backup.sh 2>&1; then
        echo "$(date) [ERRO] Segunda tentativa de atualização falhou." | tee -a "$LOG_FILE"
        exit 1
    fi
fi

echo "$(date) ---- Automação Nextcloud AIO concluída! ----" | tee -a "$LOG_FILE"
EOF

# Aplicar permissões corretas ao script
chmod +x "$SCRIPT_PATH"
echo "$(date) Script salvo em $SCRIPT_PATH" | tee -a "$LOG_FILE"

# Adicionar cronjob para execução automática
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
echo "$(date) Agendamento diário configurado para 04:00" | tee -a "$LOG_FILE"

echo "$(date) ---- Configuração concluída! ----" | tee -a "$LOG_FILE"
