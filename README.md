# nextcloud-aio\_auto-update.sh

Este script automatiza a atualização do Nextcloud AIO (All-in-One) em um servidor Linux. Ele configura um cron job para executar a atualização diariamente às 4 da manhã e oferece a opção de executar a atualização manualmente.

## Funcionalidades

* **Atualização Automática:**
    * Agendamento diário da atualização do Nextcloud AIO às 4 da manhã.
    * Utiliza o script `/daily-backup.sh` fornecido pela equipe do Nextcloud AIO para realizar a atualização.
    * Lógica de retentativa para garantir que todos os contêineres sejam atualizados corretamente.
* **Instalação Automática do `cron`:**
    * Verifica se o `cron` está instalado e, se necessário, instala-o automaticamente.
    * Suporta distribuições Linux baseadas em Debian/Ubuntu, CentOS/RHEL e Alpine Linux.
* **Logs Detalhados:**
    * Registra todas as ações e erros em `/var/log/nextcloud_aio_auto-update.log`.
* **Execução Manual:**
    * Fornece instruções claras sobre como executar a atualização manualmente.

## Pré-requisitos

* Um servidor Linux com Docker e Nextcloud AIO instalados.
* Acesso à internet para baixar o script e instalar o `cron` (se necessário).
* Privilégios de superusuário (root ou sudo).

## Instalação

1.  **Baixe e Execute o Script:**
    * Abra um terminal no seu servidor Linux.
    * Execute o seguinte comando:

        ```bash
        curl -sL https://raw.githubusercontent.com/rafaelfmuniz/automation-scripts/main/nextcloud-aio_auto-update.sh | bash
        ```

2.  **Verifique a Instalação:**
    * O script será instalado em `/root/nextcloud-aio_auto-update.sh`.
    * O agendamento (cron job) será configurado para executar às 4 da manhã.
    * Verifique se o agendamento foi criado corretamente usando o comando `crontab -l`.
    * Verifique se o serviço cron está em execução usando o comando `sudo systemctl status cron` (ou `sudo rc-status cron` para Alpine Linux).
    * Verifique o arquivo de log `/var/log/nextcloud_aio_auto-update.log` para verificar se há erros.

## Execução Manual

* Para executar a atualização manualmente, execute o seguinte comando:

    ```bash
    /root/nextcloud-aio_auto-update.sh
    ```

## Logs

* Todos os logs são armazenados em `/var/log/nextcloud_aio_auto-update.log`.

## Observações

* Certifique-se de que o seu servidor tenha acesso à internet para baixar o script e instalar o `cron`.
* O script requer privilégios de superusuário para instalar o `cron` e configurar o agendamento.
* Verifique os logs regularmente para monitorar a execução do script e identificar possíveis erros.
