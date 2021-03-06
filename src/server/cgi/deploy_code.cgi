#!/bin/bash

### Inicialização
source $(dirname $(dirname $(dirname $(readlink -f $0))))/common/sh/include.sh || exit 1
source $install_dir/sh/include.sh || exit 1

function submit_deploy() {

    if [ -z "$proceed" ]; then
        return 1

    elif [ "$proceed" == "$proceed_view" ] || [ "$proceed" == "$proceed_simulation" ]; then

        local app_simulation_clearance="$tmp_dir/app_simulation_clearance"
        local env_simulation_clearance="$tmp_dir/env_simulation_clearance"
        local app_deploy_clearance="$tmp_dir/app_deploy_clearance"
        local env_deploy_clearance="$tmp_dir/env_deploy_clearance"
        local process_group=''
        local show_simulation=false
        local show_deploy=false
        local show_form=false

        rm -f $app_simulation_clearance $env_simulation_clearance $app_deploy_clearance $env_deploy_clearance

        { test "$proceed" != "$proceed_simulation" && clearance "user" "$REMOTE_USER" "app" "$app_name" "read" && touch "$app_simulation_clearance"; } &
        process_group="$process_group $!"

        { test "$proceed" != "$proceed_simulation" && clearance "user" "$REMOTE_USER" "ambiente" "$env_name" "read" && touch "$env_simulation_clearance"; } &
        process_group="$process_group $!"

        { clearance "user" "$REMOTE_USER" "app" "$app_name" "write" && touch "$app_deploy_clearance"; } &
        process_group="$process_group $!"

        { clearance "user" "$REMOTE_USER" "ambiente" "$env_name" "write" && touch "$env_deploy_clearance"; } &
        process_group="$process_group $!"

        wait $process_group
        test -f $app_simulation_clearance && test -f $env_simulation_clearance && show_simulation=true && show_form=true
        test -f $app_deploy_clearance && test -f $env_deploy_clearance && show_deploy=true && show_form=true

        if $show_form; then

            if [ "$proceed" == "$proceed_view" ]; then
                echo "      <p><b>Parâmetros de deploy:</b></p>"
                echo "      <p>"
                echo "          <div class=\"column zero_padding cfg_color box_shadow\">"
                echo "              <table>"
                while read l; do
                    key="$(echo "$l" | cut -f1 -d '=')"
                    value="$(echo "$l" | sed -rn "s/^[^\=]+=//p" | sed -r "s/'//g" | sed -r 's/"//g')"
                    test -n "$key" || continue
                    if echo "$key" | grep -E "^#" > /dev/null; then
                        echo "                  <tr><td colspan=\"2\"><b>##$key</b></td></tr>"
                    else
                        show_param=true
                        echo "$key" | grep -Ex ".*\[.*\]" > /dev/null  && show_param=false
                        ! $show_param && echo "$key" | grep -Ex ".*\[$env_name\]" > /dev/null && show_param=true
                        $show_param && echo "              <tr><td>$key:      </td><td>$value</td></tr>"
                    fi
                done < "$app_conf_dir/$app_name.conf"
                echo "              </table>"
                echo "          </div>"
                echo "      </p>"
            fi

            echo "      <p>"
            echo "          <form action=\"$start_page\" method=\"post\">"
            echo "              <input type=\"hidden\" name=\"enable_redeploy\" value=\"$enable_redeploy\"></td></tr>"
            echo "              <input type=\"hidden\" name=\"enable_deletion\" value=\"$enable_deletion\"></td></tr>"
            echo "              <input type=\"hidden\" name=\"$app_param\" value=\"$app_name\"></td></tr>"
            echo "              <input type=\"hidden\" name=\"$rev_param\" value=\"$rev_name\"></td></tr>"
            echo "              <input type=\"hidden\" name=\"$env_param\" value=\"$env_name\"></td></tr>"
            $show_simulation && echo "              <input type=\"submit\" name=\"proceed\" value=\"$proceed_simulation\">"
            $show_deploy && echo "              <input type=\"submit\" name=\"proceed\" value=\"$proceed_deploy\">"
            echo "          </form>"
            echo "      </p>"
        else
            echo "      <p><b>Você não possui permissão de deploy.</b></p>"
        fi

    else
        return 1
    fi

    return 0

}

function cat_eof() {
    if [ -r "$1" ] && [ -n "$2" ]; then

        local file="$1"
        local eof_msg="$2"
        local eof=false
        local t=0
        local n=0
        local timeout=$(($cgi_timeout*9/10))                    # tempo máximo para variação no tamanho do arquivo: 90% do timeout do apache
        local size=$(cat "$file" | wc -l)
        local oldsize="$size"
        local line

        sed -n "1,${size}p" "$file" > $tmp_dir/file_part_$n
        grep -x "$eof_msg" $tmp_dir/file_part_$n  > /dev/null && eof=true || cat $tmp_dir/file_part_$n

        while ! $eof; do

            size=$(cat $file | wc -l)

            if [ "$size" -gt "$oldsize" ]; then

                t=0
                rm -f $tmp_dir/file_part_$n
                ((n++))
                sed -n "$((oldsize+1)),${size}p" "$file" > $tmp_dir/file_part_$n
                oldsize="$size"
                grep -x "$eof_msg" $tmp_dir/file_part_$n > /dev/null && eof=true || cat $tmp_dir/file_part_$n

            else
                sleep 1 && ((t++))
            fi

            test $t -ge $timeout && echo 'TIMEOUT' && break

        done

        while read line; do
            echo "$line"
            test "$line" == "$eof_msg" && break
        done < $tmp_dir/file_part_$n

        rm -f $tmp_dir/file_part_$n

    else
        return 1
    fi

    return 0
}

function end() {
    test "$1" == "0" || echo "      <p><b>Operação inválida.</b></p>"
    web_footer

    if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
        rm -f $tmp_dir/*
        rmdir $tmp_dir
    fi

    test -n "$sleep_pid" && kill "$sleep_pid" &> /dev/null
    clean_locks
    wait &> /dev/null

    exit $1
}

trap "end 1" SIGQUIT SIGINT SIGHUP SIGTERM
mkdir $tmp_dir

### Cabeçalho
web_header

# Inicializar variáveis e constantes
test "$REQUEST_METHOD" == "POST" && test -n "$CONTENT_LENGTH" && read -n "$CONTENT_LENGTH" POST_STRING
app_param="$(echo "${col[app]}" | sed -r 's/\[//;s/\]//')"
rev_param="$(echo "${col[rev]}" | sed -r 's/\[//;s/\]//')"
env_param="$(echo "${col[env]}" | sed -r 's/\[//;s/\]//')"
proceed_view="Continuar"
proceed_simulation="Simular"
proceed_deploy="Deploy"
membership "$REMOTE_USER" | grep -Ex 'admin' > /dev/null && enable_options=true || enable_options=false

if [ -z "$POST_STRING" ]; then

    # Formulário deploy
    echo "      <div class=\"column\">"
    echo "          <form action=\"$start_page\" method=\"post\">"
    # Sistema...
    echo "              <p>"
    echo "      		    <select class=\"select_default\" name=\"$app_param\">"
    echo "		        	<option value=\"\" selected>Sistema...</option>"
    find $app_conf_dir/ -mindepth 1 -maxdepth 1 -type f -name '*.conf' | sort | xargs -I{} -d '\n' basename {} | cut -f1 -d '.' | sed -r "s|(.*)|\t\t\t\t\t<option>\1</option>|"
    echo "		            </select>"
    echo "              </p>"
    # Ambiente...
    echo "              <p>"
    echo "      		<select class=\"select_default\" name=\"$env_param\">"
    echo "		        	<option value=\"\" selected>Ambiente...</option>"
    mklist "$ambientes" | sort | sed -r "s|(.*)|\t\t\t\t\t<option>\1</option>|"
    echo "		        </select>"
    echo "              </p>"
    # Revisão...
    echo "              <p>"
    echo "              <input type=\"text\" class=\"text_default\" name=\"$rev_param\" placeholder=\" Revisão...\"></input>"
    echo "              </p>"
    # Opções...
    if $enable_options; then
        echo "              <fieldset>"
        echo "                  <legend>Opções Avançadas</legend>"
        echo "                  <p><input type=\"checkbox\" name=\"enable_redeploy\" value=\"true\">Reexecutar último deploy</p>"
        echo "                  <p><input type=\"checkbox\" name=\"enable_deletion\" value=\"true\">Forçar modo de deleção</p>"
        echo "              </fieldset>"
    fi
    # Submit
    echo "              <p>"
    echo "              <input type=\"submit\" name=\"proceed\" value=\"$proceed_view\">"
    echo "              </p>"
    echo "          </form>"
    echo "      </div>"

else

    # Processar POST_STRING
    arg_string="&$(web_filter "$POST_STRING")&"
    enable_redeploy=$(echo "$arg_string" | sed -rn "s/^.*&enable_redeploy=([^\&]+)&.*$/\1/p")
    enable_deletion=$(echo "$arg_string" | sed -rn "s/^.*&enable_deletion=([^\&]+)&.*$/\1/p")
    app_name=$(echo "$arg_string" | sed -rn "s/^.*&$app_param=([^\&]+)&.*$/\1/p")
    rev_name=$(echo "$arg_string" | sed -rn "s/^.*&$rev_param=([^\&]+)&.*$/\1/p")
    env_name=$(echo "$arg_string" | sed -rn "s/^.*&$env_param=([^\&]+)&.*$/\1/p")
    proceed=$(echo "$arg_string" | sed -rn "s/^.*&proceed=([^\&]+)&.*$/\1/p")

    # Opções de deploy padrão
    enable_redeploy=${enable_redeploy:=false}
    enable_deletion=${enable_deletion:=false}

    if [ -n "$app_name" ] && [ -n "$rev_name" ] && [ -n "$env_name" ] && [ -n "$proceed" ]; then

        valid "$enable_redeploy" "bool" "Erro. Opção inválida." || end 1
        valid "$enable_deletion" "bool" "Erro. Opção inválida." || end 1
        valid "$app_name" "app" "Erro. Nome de aplicação inválido." || end 1
        valid "$rev_name" "rev" "Erro. Nome de revisão inválido." || end 1
        valid "$env_name" "ambiente" "Erro. Nome de ambiente inválido." || end 1

        lock "pages_${app_name}_${env_name}" "<p><b>Há outro deploy da aplicação '$app_name' no ambiente '$env_name' em execução. Tente novamente.</b></p>" || end 1

        if [ "$proceed" == "$proceed_view" ]; then

            ### Visualizar parâmetros de deploy
            echo "      <p>"
            echo "          <table>"
            echo "              <tr><td>Sistema: </td><td>$app_name</td></tr>"
            echo "              <tr><td>Revisão: </td><td>$rev_name</td></tr>"
            echo "              <tr><td>Ambiente: </td><td>$env_name</td></tr>"
            if $enable_options; then
                $enable_redeploy && echo "              <tr><td>Opção: </td><td>Reexecutar último deploy</td></tr>"
                $enable_deletion && echo "              <tr><td>Opção: </td><td>Forçar modo de deleção</td></tr>"
            fi
            echo "          </table>"
            echo "      </p>"

            submit_deploy

        else

            test -p "$deploy_queue" || end 1
            sleep $cgi_timeout > "$deploy_queue" &
            sleep_pid=$!
            test -n "$REMOTE_USER" && user_name="$REMOTE_USER" || user_name="$(id --user --name)"
            deploy_options="-u $user_name"
            if $enable_options; then
                $enable_redeploy && deploy_options="${deploy_options} -r"
                $enable_deletion && deploy_options="${deploy_options} -d"
            fi
            deploy_out="$tmp_dir/deploy.out"
            touch $deploy_out

            if [ "$proceed" == "$proceed_simulation" ]; then

                ### Simular deploy
                deploy_options="${deploy_options} -n"
                echo "$deploy_options:$app_name:$rev_name:$env_name:$deploy_out:" >> "$deploy_queue"

                echo "      <p>"
                echo "          <div class=\"cfg_color column box_shadow\">"
                echo "              <pre>"
                cat_eof "$deploy_out" "$end_msg"
                echo "              </pre>"
                echo "          </div>"
                echo "      </p>"

                submit_deploy

            elif [ "$proceed" == "$proceed_deploy" ]; then

                ### Executar deploy
                echo "$deploy_options:$app_name:$rev_name:$env_name:$deploy_out:" >> "$deploy_queue"

                echo "      <p>"
                echo "          <div class=\"cfg_color column box_shadow\">"
                echo "              <pre>"
                cat_eof "$deploy_out" "$end_msg"
                echo "              </pre>"
                echo "          </div>"
                echo "      </p>"

            fi
        fi
    else
        echo "      <p><b>Erro. Os parâmetro 'Sistema', 'Ambiente' e 'Revisão' devem ser preenchidos.</b></p>"
    fi
fi

end 0
