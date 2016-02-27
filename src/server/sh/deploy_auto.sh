#!/bin/bash
source $(dirname $(dirname $(dirname $(readlink -f $0))))/common/sh/include.sh || exit 1
source $install_dir/sh/include.sh || exit 1

lock_history=false
interactive=false
execution_mode="server"
verbosity="quiet"
running=0

function async_deploy() {

    test "$#" -lt "$4" && return 1
    test "$#" -gt "$5" && return 1
    test ! -d "$tmp_dir" && return 1

    local options="$1"
    local app_name="$2"
    local rev_name="$3"
    local env_name="$4"
    local out_name="$5"

    miliseconds=$(date +%s%3N)
    echo '' > $tmp_dir/deploy_$miliseconds.log
    log "INFO" "DEPLOY (opts:$options app:$app_name rev:$rev_name env:$env_name out:$out_name)\n" &>> $tmp_dir/deploy_$miliseconds.log

    if [ -z "$out_name" ]; then
        nohup $install_dir/sh/deploy_pages.sh "$options" "$app_name" "$rev_name" "$env_name" &>> $tmp_dir/deploy_$miliseconds.log &
    else
        touch &>> "$out_name" || return 1
        nohup $install_dir/sh/deploy_pages.sh "$options" "$app_name" "$rev_name" "$env_name" &>> "$out_name" &
    fi

    sleep 0.001

    ((running++))
    if [ "$running" -eq "$max_running" ]; then
        wait
        running=0
        find $tmp_dir/ -maxdepth 1 -type f -iname 'deploy_*.log' | sort | xargs cat
        rm -f $tmp_dir/*.log
    fi

    return 0

}

function end {

    break 10 2> /dev/null
    trap "" SIGQUIT SIGTERM SIGINT SIGHUP
    erro=$1

    wait
    find $tmp_dir/ -maxdepth 1 -type f -iname 'deploy_*.log' | sort | xargs cat

    if [ -d $tmp_dir ]; then
        rm -f $tmp_dir/*
        rmdir $tmp_dir
    fi

    clean_locks

    exit $erro

}

trap "end 1" SIGQUIT SIGTERM SIGINT SIGHUP

##################### Deploy em todos os ambientes #####################

if [ -z "$ambientes" ]; then
    echo 'Favor preencher corretamente o arquivo global.conf e tentar novamente.'
    exit 1
fi

lock 'deploy_auto' "Rotina de deploy automático em andamento..."
mkdir -p $tmp_dir
mklist "$ambientes" "$tmp_dir/lista_ambientes"

while read ambiente; do

    grep -REl "^auto_$ambiente='1'$" $app_conf_dir > $tmp_dir/lista_aplicacoes
    sed -i -r "s|^$app_conf_dir/(.+)\.conf$|\1|g" $tmp_dir/lista_aplicacoes

    if [ -n "$(cat $tmp_dir/lista_aplicacoes)" ]; then

        log "INFO" "Iniciando deploys automáticos no ambiente '$ambiente'\n"

        while read aplicacao; do

            async_deploy "-f" "$aplicacao" "auto" "$ambiente"

        done < "$tmp_dir/lista_aplicacoes"

    else

        log "INFO" "O deploy automático não foi habilitado no ambiente '$ambiente'\n"

    fi

done < "$tmp_dir/lista_ambientes"

end 0
