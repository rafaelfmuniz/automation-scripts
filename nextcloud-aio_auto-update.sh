#!/bin/bash

SCRIPT_NAME="nextcloud-aio_auto-update.sh"
SCRIPT_PATH="/root/$SCRIPT_NAME"
LOG_FILE="/var/log/nextcloud_aio_auto-update.log"
SCHEDULE_TIME="04:00"
CRON_JOB="0 4 * * * /root/$SCRIPT_NAME >> $LOG_FILE 2>&1"

echo "$(date) ---- Configurando automação Nextcloud AIO ----" | tee -a "$LOG_FILE"

# Verificar se o cron está instalado
if ! command -v crontab &> /dev/null; then
    echo "$(date) Cron não encontrado. Instalando..." | tee -a "$LOG_FILE"

    # Instalar cron (detectar distribuição)
    if [[ -f /etc/debian_version ]]; then
        apt-get update && apt-get install -y cron
    elif [[ -f /etc/redhat-release ]]; then
        yum install -y cron && systemctl enable crond && systemctl start crond
    elif [[ -f /etc/alpine-release ]]; then
        apk update && apk add cron && rc-update add cron default && rc-service cron start
    else
        echo "$(date) [ERRO] Distribuição não reconhecida. Instale o cron manualmente." | tee -a "$LOG_FILE"
        exit 1
    fi

    echo "$(date) Cron instalado com sucesso." | tee -a "$LOG_FILE"
fi

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

# Mensagem final com instruções para execução manual
echo "$(date) A automação foi configurada para executar às 4 da manhã." | tee -a "$LOG_FILE"
echo "$(date) Se você deseja executar a atualização manualmente agora, execute o seguinte comando:" | tee -a "$LOG_FILE"
echo "$(date) /root/$SCRIPT_NAME" | tee -a "$LOG_FILE"

echo "$(date) ---- Configuração concluída! ----" | tee -a "$LOG_FILE"
