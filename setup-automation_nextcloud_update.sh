#!/bin/bash

# Definição de variáveis
BACKUP_SCRIPT="/root/shutdown-script.sh"
UPDATE_SCRIPT="/root/automatic-updates.sh"
LOG_FILE="/var/log/container-maintenance.log"
CRON_JOB_BACKUP="0 4 * * * /root/shutdown-script.sh >> /var/log/container-maintenance.log 2>&1"
CRON_JOB_UPDATE="5 4 * * * /root/automatic-updates.sh >> /var/log/container-maintenance.log 2>&1"

# Criando o script de backup e desligamento
cat <<EOF > $BACKUP_SCRIPT
#!/bin/bash

echo "\$(date) - Iniciando backup e parada dos containers" >> $LOG_FILE
docker exec --env STOP_CONTAINERS=1 nextcloud-aio-mastercontainer /daily-backup.sh
echo "\$(date) - Containers parados. Backup concluído." >> $LOG_FILE
EOF

# Criando o script de atualização automática
cat <<EOF > $UPDATE_SCRIPT
#!/bin/bash

echo "\$(date) - Verificando se os containers foram parados..." >> $LOG_FILE

# Aguarda até que os containers estejam parados ou até 5 minutos
TIMER=0
while docker ps --format "{{.Names}}" | grep -q "^nextcloud-aio-mastercontainer$"; do
    if [[ \$TIMER -ge 300 ]]; then
        echo "\$(date) - Tempo máximo de espera atingido. Continuando a atualização." >> $LOG_FILE
        break
    fi
    echo "\$(date) - Containers ainda em execução. Aguardando..." >> $LOG_FILE
    sleep 10
    TIMER=\$((TIMER + 10))
done

echo "\$(date) - Iniciando atualização dos containers." >> $LOG_FILE
docker exec --env AUTOMATIC_UPDATES=1 nextcloud-aio-mastercontainer /daily-backup.sh
echo "\$(date) - Atualização concluída." >> $LOG_FILE
EOF

# Aplicando permissões corretas aos scripts
chmod 700 $BACKUP_SCRIPT $UPDATE_SCRIPT
chown root:root $BACKUP_SCRIPT $UPDATE_SCRIPT

# Configurando as tarefas no cron
(crontab -u root -l 2>/dev/null | grep -v "$BACKUP_SCRIPT"; echo "$CRON_JOB_BACKUP") | crontab -u root -
(crontab -u root -l 2>/dev/null | grep -v "$UPDATE_SCRIPT"; echo "$CRON_JOB_UPDATE") | crontab -u root -

echo "Automação configurada com sucesso!"
echo "Backup programado para 04:00 e atualização será feita após 5 minutos ou quando os containers pararem."

