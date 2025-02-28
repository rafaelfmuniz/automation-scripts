#!/bin/bash

LOG_FILE="/var/log/nextcloud_aio_automation.log"
SCRIPT_PATH="/root/nextcloud_aio_automation.sh"
CRON_JOB="0 4 * * * /root/nextcloud_aio_automation.sh >> /var/log/nextcloud_aio_automation.log 2>&1"

echo "---- Configurando automação Nextcloud AIO ----" | tee -a "$LOG_FILE"

# Criar uma cópia local do script
cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

LOG_FILE="/var/log/nextcloud_aio_automation.log"
echo "---- Iniciando automação Nextcloud AIO ----" | tee -a "$LOG_FILE"

echo "[1/3] Parando os containers..." | tee -a "$LOG_FILE"
docker exec --env STOP_CONTAINERS=1 nextcloud-aio-mastercontainer /daily-backup.sh

# Aguarde até que todos os containers, exceto o mastercontainer, sejam parados
TIMEOUT=300  # Tempo máximo de espera (5 minutos)
INTERVAL=10  # Intervalo de verificação (10 segundos)
WAIT_TIME=0

while docker ps --format "{{.Names}}" | grep -v "^nextcloud-aio-mastercontainer$" | grep -q .; do
    if [ "$WAIT_TIME" -ge "$TIMEOUT" ]; then
        echo "[ERRO] Tempo limite atingido! Alguns containers ainda estão rodando." | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "Aguardando containers pararem... ($WAIT_TIME segundos)" | tee -a "$LOG_FILE"
    sleep "$INTERVAL"
    WAIT_TIME=$((WAIT_TIME + INTERVAL))
done

echo "[2/3] Todos os containers (exceto o master) foram parados! Iniciando atualização..." | tee -a "$LOG_FILE"

# Executa a atualização
if ! docker exec --env AUTOMATIC_UPDATES=1 nextcloud-aio-mastercontainer /daily-backup.sh; then
    echo "[ERRO] Falha na primeira tentativa de atualização. Tentando novamente..." | tee -a "$LOG_FILE"

    # Espera o mastercontainer reiniciar, se necessário
    while ! docker ps --format "{{.Names}}" | grep -q "^nextcloud-aio-mastercontainer$"; do
        echo "Aguardando Mastercontainer reiniciar..." | tee -a "$LOG_FILE"
        sleep 30
    done
    
    echo "[3/3] Rodando atualização novamente para garantir que tudo foi atualizado corretamente." | tee -a "$LOG_FILE"
    docker exec --env AUTOMATIC_UPDATES=1 nextcloud-aio-mastercontainer /daily-backup.sh
fi

echo "---- Automação Nextcloud AIO concluída! ----" | tee -a "$LOG_FILE"
EOF

# Aplicar permissões corretas ao script
chmod +x "$SCRIPT_PATH"
echo "Script salvo em $SCRIPT_PATH" | tee -a "$LOG_FILE"

# Adicionar cronjob para execução automática
(crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH"; echo "$CRON_JOB") | crontab -
echo "Agendamento diário configurado para 04:00" | tee -a "$LOG_FILE"

echo "---- Configuração concluída! ----" | tee -a "$LOG_FILE"

