#!/bin/bash

# Copyright (c) 2024 rafaelfmuniz
# Author: rafaelfmuniz
# License: MIT

SCRIPT_NAME="nextcloud-aio_auto-update.sh"
SCRIPT_PATH="/root/$SCRIPT_NAME"
LOG_FILE="/var/log/nextcloud_aio_auto-update.log"
SCHEDULE_TIME="04:00" # Hora padrão
CRON_JOB="0 4 * * * /root/$SCRIPT_NAME >> $LOG_FILE 2>&1"

HEADER_TEXT="NextCloud AIO Auto Update\n-------------------------\n\nEste script irá configurar a atualização automática do Nextcloud AIO."
INITIAL_INFO_TEXT="Este script irá configurar a atualização automática do Nextcloud AIO."
CONFIRMATION_TEXT="Deseja iniciar a configuração da atualização automática do Nextcloud AIO?"
CRON_INSTALL_INFO="Cron não encontrado. Instalando..."
CRON_INSTALLED_OK="Cron instalado com sucesso."
DISTRO_RECOG_ERROR="Distribuição não reconhecida. Instale o cron manualmente."
CRON_INSTALL_FAILED="Falha na instalação do Cron. Configuração interrompida."
LOCAL_SCRIPT_CREATE_INFO="Criando script de atualização local..."
LOCAL_SCRIPT_CREATE_OK="Script de atualização local criado."
LOCAL_SCRIPT_CREATE_FAILED="Falha ao criar script de atualização local. Configuração interrompida."
SCHEDULE_INFO="Agendando atualização para as %s..."
SCHEDULE_OK="Agendamento configurado para as %s."
MANUAL_EXEC_PROMPT="A automação foi configurada para executar diariamente às %s."
CONFIG_COMPLETE_OK="Configuração concluída."
CONFIG_CANCELLED_ERROR="Configuração cancelada pelo usuário."
CONFIG_NOT_COMPLETED_ERROR="A configuração da atualização automática não foi concluída."
SCHEDULE_TIME_PROMPT="Informe a hora desejada para agendar a atualização automática (formato HH:MM, ex: 03:30):"
MANUAL_EXEC_CONFIRM_PROMPT="Deseja executar o script de atualização manualmente agora para testar a configuração?"
PREVIOUS_INSTALL_DETECTED="Uma instalação anterior do script foi detectada.\n\nPara evitar conflitos, o script anterior e o agendamento cron serão removidos.\n\nDeseja continuar e substituir a instalação anterior?"
PREVIOUS_INSTALL_REMOVED="Instalação anterior e agendamento removidos."
PREVIOUS_INSTALL_NOT_REMOVED="Remoção da instalação anterior cancelada."
RUN_MANUAL_UPDATE_PROMPT="Deseja executar a atualização manualmente agora para verificar se está tudo funcionando corretamente?"
MANUAL_UPDATE_RUNNING="Executando script de atualização manual..."
MANUAL_UPDATE_COMPLETED="Script de atualização manual concluído. Verifique o log em $LOG_FILE para detalhes."
FINAL_SCREEN_CONFIRM_PROMPT="A configuração da atualização automática foi concluída.\n\nDeseja executar o script de atualização manualmente agora?"
FINAL_SCREEN_INFO="A automação foi configurada para executar diariamente às %s."


header_info() {
    whiptail --title "NextCloud AIO Auto Update" --msgbox "$HEADER_TEXT" 12 70 --ok-button Ok --nocancel
}

msg_info() {
    local msg="$1"
    printf "Informação: %s\n" "$msg"
}

msg_ok() {
    local msg="$1"
    printf "Sucesso: ✓ %s\n" "$msg"
}

msg_error() {
    local msg="$1"
    whiptail --title "Erro" --msgbox "✗ ${msg}" 10 70 --ok-button Ok --nocancel
}

install_cron() {
    msg_info "$CRON_INSTALL_INFO"
    if ! command -v crontab &>/dev/null; then
        if [[ -f /etc/debian_version ]]; then
            apt-get update && apt-get install -y cron &>/dev/null
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y cron &>/dev/null && systemctl enable crond &>/dev/null && systemctl start crond &>/dev/null
        elif [[ -f /etc/alpine-release ]]; then
            apk update && apk add cron &>/dev/null && rc-update add cron default &>/dev/null && rc-service cron start &>/dev/null
        else
            msg_error "$DISTRO_RECOG_ERROR"
            return 1
        fi
        msg_ok "$CRON_INSTALLED_OK"
        return 0
    else
        msg_ok "Cron já está instalado."
        return 0
    fi
}

create_local_script() {
    msg_info "$LOCAL_SCRIPT_CREATE_INFO"
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
    msg_ok "$LOCAL_SCRIPT_CREATE_OK"
    return 0
}

schedule_cronjob() {
    msg_info "$(printf "$SCHEDULE_INFO" "$SCHEDULE_TIME")"
    CRON_JOB="0 $(echo "$SCHEDULE_TIME" | cut -d':' -f1) * * * /root/$SCRIPT_NAME >> $LOG_FILE 2>&1"
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    msg_ok "$(printf "$SCHEDULE_OK" "$SCHEDULE_TIME")"
    return 0
}

remove_previous_installation() {
    msg_info "$PREVIOUS_INSTALL_DETECTED" # DEBUG - Message before previous install removal
    if [[ -f "$SCRIPT_PATH" ]] || crontab -l 2>/dev/null | grep -q "$SCRIPT_NAME"; then
        msg_info "Removendo instalação anterior..."
        rm -f "$SCRIPT_PATH"
        crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME" | crontab -
        msg_ok "$PREVIOUS_INSTALL_REMOVED"
    else
        msg_info "Nenhuma instalação anterior detectada." # DEBUG - Message if no previous install
    fi
}


start_routines() {
    msg_info "Iniciando rotinas de configuração..." # DEBUG - Start of start_routines

    # Verificar se existe instalação anterior
    remove_previous_installation # Call remove_previous_installation directly

    # Verificar se o cron está instalado
    msg_info "Verificando instalação do Cron..." # DEBUG - Before cron install check
    if ! install_cron; then
        msg_error "$CRON_INSTALL_FAILED"
        return 1
    fi
    msg_info "Cron instalado ou já presente." # DEBUG - After cron install check

    # Criar script local
    msg_info "Criando script local..." # DEBUG - Before local script creation
    if ! create_local_script; then
        msg_error "$LOCAL_SCRIPT_CREATE_FAILED"
        return 1
    fi
    msg_info "Script local criado." # DEBUG - After local script creation

    # Agendar cronjob
    msg_info "Agendando cronjob..." # DEBUG - Before cron schedule
    schedule_cronjob
    msg_info "Cronjob agendado." # DEBUG - After cron schedule

    msg_info "Rotinas de configuração completas." # DEBUG - End of start_routines
    return 0
}


header_info

# Pergunta de confirmação usando whiptail --yesno
if whiptail --title "Confirmação" --yesno "$CONFIRMATION_TEXT" 12 70 --defaultno; then
    msg_info "Configuração iniciada pelo usuário." # DEBUG - Config started

    # Pergunta pela hora de agendamento
    SCHEDULE_TIME=$(whiptail --title "Agendamento" --inputbox "$SCHEDULE_TIME_PROMPT" 12 70 "$SCHEDULE_TIME" --ok-button Ok --cancel-button Cancel 3>&1 1>&2 2>&3)

    if [[ $? -eq 1 ]]; then # Cancel pressed
        msg_error "$CONFIG_CANCELLED_ERROR"
        exit 1
    fi
    msg_info "Hora de agendamento definida: $SCHEDULE_TIME" # DEBUG - Schedule time set

    if ! start_routines; then
        msg_error "$CONFIG_NOT_COMPLETED_ERROR"
        exit 1
    fi
    msg_info "Rotinas start_routines finalizadas." # DEBUG - start_routines finished

    # Pergunta se deseja executar a atualização manual (AGORA CORRETO)
    MANUAL_EXEC_CONFIRM=$(whiptail --title "Concluído" --yesno "$FINAL_SCREEN_CONFIRM_PROMPT\n\n$(printf "$FINAL_SCREEN_INFO" "$SCHEDULE_TIME")" 18 75 --defaultno)

    if [[ "$MANUAL_EXEC_CONFIRM" == "0" ]]; then
        msg_info "$MANUAL_UPDATE_RUNNING"
        /root/nextcloud-aio_auto-update.sh
        msg_ok "$MANUAL_UPDATE_COMPLETED"
    fi
    msg_info "Execução manual e tela final completas." # DEBUG - Manual exec and final screen finished

    msg_ok "$CONFIG_COMPLETE_OK"
    msg_info "Configuração completamente finalizada." # DEBUG - Config completely finished

    exit 0
else
    msg_error "$CONFIG_CANCELLED_ERROR"
    exit 1
fi
