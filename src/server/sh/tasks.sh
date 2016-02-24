#!/bin/bash
source $(dirname $(dirname $(dirname $(readlink -f $0))))/common/sh/include.sh || exit 1
source $install_dir/sh/init.sh || exit 1

lock_history=false
interactive=false
execution_mode="server"
verbosity="quiet"
pid="$$"

##### Execução somente como usuário root ######

if [ ! "$USER" == 'root' ]; then
    echo "Requer usuário root."
    exit 1
fi

#### Funções ####

function tasks () {

    mkdir -p $tmp_dir

    ### Executar rotina de deploys automáticos (no máximo um processo rodando em plano de fundo)

    auto_running=$(pgrep -f $install_dir/sh/deploy_auto.sh | wc -l)
    test "$auto_running" -eq 0 && $install_dir/sh/deploy_auto.sh &

    ### Executar deploys solicitados via browser (pendente)

    ### Expurgo de logs

    while [ -f "$lock_dir/$history_lock_file" ]; do
        sleep 1
    done

    lock_history=true
    touch $lock_dir/$history_lock_file

    # 1) cron
    touch $history_dir/$cron_log_file
    tail --lines=$cron_log_size $history_dir/$cron_log_file > $tmp_dir/cron_log_new
    cp -f $tmp_dir/cron_log_new $history_dir/$cron_log_file

    # 2) Histórico de deploys
    local qtd_history
    local qtd_purge

    if [ -f "$history_dir/$history_csv_file" ]; then
        qtd_history=$(cat "$history_dir/$history_csv_file" | wc -l)
        if [ $qtd_history -gt $global_history_size ]; then
            qtd_purge=$(($qtd_history - $global_history_size))
            sed -i "2,${qtd_purge}d" "$history_dir/$history_csv_file"
        fi
    fi

    # 3) logs de deploy de aplicações
    find ${app_history_dir_tree} -mindepth 1 -maxdepth 1 -type d > $tmp_dir/app_history_path
    while read path; do
        app_history_dir="${app_history_dir_tree}/$(basename $path)"
        find "${app_history_dir}/" -mindepth 1 -maxdepth 1 -type d | sort > $tmp_dir/logs_total
        tail $tmp_dir/logs_total --lines=${app_log_max} > $tmp_dir/logs_ultimos
        grep -vxF --file=$tmp_dir/logs_ultimos $tmp_dir/logs_total > $tmp_dir/logs_expurgo
        cat $tmp_dir/logs_expurgo | xargs --no-run-if-empty rm -Rf
    done < $tmp_dir/app_history_path

    # Remove arquivos temporários
    rm -f $tmp_dir/*
    rmdir $tmp_dir

    # Destrava histórico de deploy
    rm -f $lock_dir/$history_lock_file
    lock_history=false

}

function end {

    trap "" SIGQUIT SIGTERM SIGINT SIGHUP
    erro=$1
    break 10 2> /dev/null
    wait

    if [ -d $tmp_dir ]; then
        rm -f $tmp_dir/*
        rmdir $tmp_dir
    fi

    if [ -f $lock_dir/server_cron_tasks ]; then
        rm -f "$lock_dir/server_cron_tasks"
    fi

    if $lock_history; then
        rm -f "$lock_dir/$deploy_log_edit"
    fi

    unix2dos $history_dir/$cron_log_file > /dev/null 2>&1

    return $erro

}

trap "end 1" SIGQUIT SIGTERM SIGINT SIGHUP

if [ -z "$ambientes" ]; then
    echo 'Favor preencher corretamente o arquivo global.conf e tentar novamente.'
    exit 1
fi

lock 'deploy_service' "O serviço já está em execução."

valid "cron_log_size" "regex_qtd" "\nErro. Tamanho inválido para o log de tarefas agendadas."
valid "app_log_max" "regex_qtd" "\nErro. Valor inválido para a quantidade de logs de aplicações."
valid "global_history_size" "regex_qtd" "\nErro. Tamanho inválido para o histórico global."

while true; do
    sleep 1
    tasks >> $history_dir/$cron_log_file 2>&1
done