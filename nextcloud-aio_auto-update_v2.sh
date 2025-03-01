#!/bin/bash

# Copyright (c) 2024 rafaelfmuniz
# Author: rafaelfmuniz
# License: MIT

SCRIPT_NAME="nextcloud-aio_auto-update.sh"
SCRIPT_PATH="/root/$SCRIPT_NAME"
LOG_FILE="/var/log/nextcloud_aio_auto-update.log"
SCHEDULE_TIME="04:00"
CRON_JOB="0 4 * * * /root/$SCRIPT_NAME >> $LOG_FILE 2>&1"

header_info() {
    whiptail --title "NextCloud AIO Auto Update" --msgbox "NextCloud AIO Auto Update\n-------------------------\n\nEste script irá configurar a atualização automática do Nextcloud AIO." 12 70 --ok-button Ok --nocancel
}

msg_info() {
    local msg="$1"
    whiptail --title "Info" --msgbox "${msg}" 10 70 --ok-button Ok --nocancel
}

msg_ok() {
    local msg="$1"
    whiptail --title "Success" --msgbox "✓ ${msg}" 10 70 --ok-button Ok --nocancel
}

msg_error() {
    local msg="$1"
    whiptail --title "Error" --msgbox "✗ ${msg}" 10 70 --ok-button Ok --nocancel
}

install_cron() {
    msg_info "Cron não encontrado. Instalando..."
    if [[ -f /etc/debian_version ]]; then
        apt-get update && apt-get install -y cron &>/dev/null
    elif [[ -f /etc/redhat-release ]]; then
        yum install -y cron &>/dev/null && systemctl enable crond &>/dev/null && systemctl start crond &>/dev/null
    elif [[ -f /etc/alpine-release ]]; then
        apk update && apk add cron &>/dev/null && rc-update add cron default &>/dev/null && rc-service cron start &>/dev/null
    else
        msg_error "Distribuição não reconhecida. Instale o cron manualmente."
        return 1
    fi
    msg_ok "Cron instalado com sucesso."
    return 0
}

create_local_script() {
    msg_info "Criando script de atualização local..."
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
    chmod +x "$SCRIPT_PATH"
    msg_ok "Script de atualização local criado."
}

schedule_cronjob() {
    msg_info "Agendando atualização para as $SCHEDULE_TIME..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    msg_ok "Agendamento configurado para as $SCHEDULE_TIME."
}


start_routines() {
    header_info

    # Verificar se o cron está instalado
    if ! command -v crontab &> /dev/null; then
        if ! install_cron; then
            msg_error "Falha na instalação do Cron. Configuração interrompida."
            return 1
        fi
    fi

    # Criar script local
    if ! create_local_script; then
        msg_error "Falha ao criar script de atualização local. Configuração interrompida."
        return 1
    fi

    # Agendar cronjob
    schedule_cronjob

    # Mensagem final com instruções para execução manual
    whiptail --title "Concluído" --msgbox "A automação foi configurada para executar diariamente às $SCHEDULE_TIME.\n\nSe você deseja executar a atualização manualmente agora, execute o seguinte comando:\n\n/root/nextcloud-aio_auto-update.sh" 18 75 --ok-button Ok --nocancel
    msg_ok "Configuração concluída."
    return 0
}


header_info

# Pergunta de confirmação usando whiptail --yesno
if whiptail --title "Confirmação" --yesno "Deseja iniciar a configuração da atualização automática do Nextcloud AIO?" 12 70 --defaultno; then
    if start_routines; then
        exit 0
    else
        msg_error "A configuração da atualização automática não foi concluída."
        exit 1
    fi
else
    msg_error "Configuração cancelada pelo usuário."
    exit 1
fi
