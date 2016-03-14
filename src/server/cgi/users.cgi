#!/bin/bash

### Inicialização
source $(dirname $(dirname $(dirname $(readlink -f $0))))/common/sh/include.sh || exit 1
source $install_dir/sh/include.sh || exit 1

function end() {

    web_footer

    if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
        rm -f $tmp_dir/*
        rmdir $tmp_dir
    fi

    clean_locks

    wait
    exit $1
}

trap "end 1" SIGQUIT SIGINT SIGHUP
mkdir $tmp_dir

### Cabeçalho
web_header

# Inicializar variáveis e constantes
test "$REQUEST_METHOD" == "POST" && test -n "$CONTENT_LENGTH" && read -n "$CONTENT_LENGTH" POST_STRING
mklist "$ambientes" "$tmp_dir/lista_ambientes"
operation_erase="Remover"
operation_groups="Gerenciar Grupos"
operation_permissions="Gerenciar Permissoes"
submit_continue="Continuar"
submit_erase_yes="Sim"
submit_erase_no="Nao"
submit_groups="Atualizar Grupos"
submit_permission_add="Adicionar"
submit_permission_erase="Remover"
submit_permission_save="Salvar"

if [ -z "$POST_STRING" ]; then

    # Formulário de pesquisa
    echo "      <p>"
    echo "          <form action=\"$start_page\" method=\"post\">"
    # Usuário...
    echo "              <p>Gerenciar usuário:</p>"
    echo "              <p>"
    echo "                  <select class=\"select_default\" name=\"user\">"
    cut -f1 -d ':' $web_users_file | sed -r "s|(.*)|\t\t\t\t\t\t<option>\1</option>|"
    echo "                  </select>"
    echo "              </p>"
    # Operação...
    echo "              <p>Operação:</p>"
    echo "              <input type=\"radio\" name=\"operation\" value=\"$operation_erase\"> $operation_erase<br>"
    echo "              <input type=\"radio\" name=\"operation\" value=\"$operation_groups\"> $operation_groups<br>"
    echo "              <input type=\"radio\" name=\"operation\" value=\"$operation_permissions\" checked> $operation_permissions<br>"
    # Submit
    echo "              <p><input type=\"submit\" name=\"submit\" value=\"$submit_continue\"></p>"
    echo "          </form>"
    echo "      </p>"

else

    arg_string="&$(web_filter "$POST_STRING")&"
    user="$(echo "$arg_string" | sed -rn "s/^.*&user=([^\&]+)&.*$/\1/p")"
    operation="$(echo "$arg_string" | sed -rn "s/^.*&operation=([^\&]+)&.*$/\1/p")"
    submit="$(echo "$arg_string" | sed -rn "s/^.*&submit=([^\&]+)&.*$/\1/p")"

    if [ -n "$user" ] && [ -n "$operation" ] && [ -n "$submit" ]; then

        case "$operation" in

            "$operation_erase")
                case "$submit" in

                    "$submit_continue")
                        echo "      <p>"
                        echo "          <b>Tem certeza de que deseja remover o usuário $user?</b>"
                        echo "          <form action=\"$start_page\" method=\"post\">"
                        echo "              <input type=\"hidden\" name=\"user\" value=\"$user\"></td></tr>"
                        echo "              <input type=\"hidden\" name=\"operation\" value=\"$operation\"></td></tr>"
                        echo "              <input type=\"submit\" name=\"submit\" value=\"$submit_erase_yes\">"
                        echo "              <input type=\"submit\" name=\"submit\" value=\"$submit_erase_no\">"
                        echo "          </form>"
                        echo "      </p>"
                        ;;

                    "$submit_erase_yes")
                        membership "$user" | while read group; do
                            unsubscribe "$user" "$group" || end 1
                            echo "      <p>Usuário '$user' retirado do grupo "$group".</p>"
                        done
                        delete_login "$user" || end 1
                        echo "      <p><b>Usuário $user removido.</b></p>"
                        ;;

                    "$submit_erase_no" )
                        echo "      <p><b>Remoção do usuário $user cancelada.</b></p>"
                        ;;

                esac
                ;;

            "$operation_groups")
                case "$submit" in

                    "$submit_continue")

                        cut -f1 -d ':' $web_groups_file > $tmp_dir/groups_all
                        membership "$user" > $tmp_dir/groups_checked
                        grep -vxF --file=$tmp_dir/groups_checked $tmp_dir/groups_all > $tmp_dir/groups_unchecked

                        echo "      <p>"
                        echo "          Selecione os grupos desejados para o usuário $user:<br>"
                        echo "          <form action=\"$start_page\" method=\"post\">"
                        echo "              <input type=\"hidden\" name=\"user\" value=\"$user\">"
                        echo "              <input type=\"hidden\" name=\"operation\" value=\"$operation\"></td></tr>"
                        cat "$tmp_dir/groups_checked" | sort | sed -r "s|(.*)|\t\t\t\t\t\t<input type=\"checkbox\" name=\"group\" value=\"\1\" checked>\1<br>|"
                        cat "$tmp_dir/groups_unchecked" | sort | sed -r "s|(.*)|\t\t\t\t\t\t<input type=\"checkbox\" name=\"group\" value=\"\1\">\1<br>|"
                        echo "              <p><input type=\"submit\" name=\"submit\" value=\"$submit_groups\"></p>"
                        echo "          </form>"
                        echo "      </p>"
                        ;;

                    "$submit_groups")

                        membership "$user" > $tmp_dir/groups_user
                        touch $tmp_dir/groups_checked
                        group="$(echo "$arg_string" | sed -rn "s/^.*&group=([^\&]+)&.*$/\1/p")"

                        while [ -n "$group" ]; do
                            echo "$group" >> $tmp_dir/groups_checked
                            arg_string="$(echo "$arg_string" | sed -r "s/&group=$group//")"
                            group="$(echo "$arg_string" | sed -rn "s/^.*&group=([^\&]+)&.*$/\1/p")"
                        done

                        grep -vxF --file=$tmp_dir/groups_checked $tmp_dir/groups_user > $tmp_dir/groups_unsubscribe

                        while read remove_group; do
                            unsubscribe "$user" "$remove_group"
                            echo "      <p>Usuário '$user' removido do grupo "$remove_group".</p>"
                        done < $tmp_dir/groups_unsubscribe

                        grep -vxF --file=$tmp_dir/groups_user $tmp_dir/groups_checked > $tmp_dir/groups_subscribe

                        while read add_group; do
                            subscribe "$user" "$add_group"
                            echo "      <p>Usuário '$user' adicionado ao grupo "$add_group".</p>"
                        done < $tmp_dir/groups_subscribe

                        echo "      <p><b>Grupos do usuário '$user' atualizados com sucesso!</b></p>"
                        ;;

                esac
                ;;

            "$operation_permissions")
                case "$submit" in

                    "$submit_continue")

                        touch "$tmp_dir/form_output"
                        erase_option=false

                        if [ "$(cat "$web_permissions_file" | wc -l)" -ge 2 ]; then
                            query_file.sh --delim "$delim" --replace-delim "</td><td>" --header 1 \
                                --select $col_resource_type $col_resource_name $col_permission \
                                --from "$web_permissions_file" \
                                --where $col_subject_type=='user' $col_subject_name=="$user" \
                                --order-by $col_resource_type $col_subject_name asc \
                                > $tmp_dir/permissions_user

                            if [ "$(cat "$tmp_dir/permissions_user" | wc -l)" -ge 1 ]; then
                                erase_option=true

                                query_file.sh --delim "$delim" --replace-delim "</th><th>" \
                                    --select $col_resource_type $col_resource_name $col_permission \
                                    --top 1 \
                                    --from "$web_permissions_file" \
                                    > $tmp_dir/permissions_header

                                sed -i -r "s|<th>$|</tr>|" "$tmp_dir/permissions_header"
                                sed -i -r 's|^(.*)$|<tr><th></th><th>\1|' "$tmp_dir/permissions_header"

                                sed -i -r "s|<td>$|</tr>|" "$tmp_dir/permissions_user"
                                sed -i -r "s|^(.*)$|<tr><td><input type=\"checkbox\" name=\"permission_string\" value=\"\1\"></td><td>\1|" "$tmp_dir/permissions_user"
                                sed -i -r "s|value=\"(.*)</td><td>(.*)</td><td>(.*)</td></tr>\">|value=\"user:$user:\1:\2:\3:\">|" "$tmp_dir/permissions_user"

                                echo "          </p>Permissões do usuário '$user':<p>" >> "$tmp_dir/form_output"
                                echo "          <table border=1>" >> "$tmp_dir/form_output"
                                cat "$tmp_dir/permissions_header" >> "$tmp_dir/form_output"
                                cat "$tmp_dir/permissions_user" >> "$tmp_dir/form_output"
                                echo "          </table>" >> "$tmp_dir/form_output"

                            else
                                echo "<p>Não há permissões registradas para o usuário "$user".</p>"
                            fi

                        else
                            echo "<p>Não há permissões registradas.</p>"
                        fi

                        echo "      <p>"
                        echo "          <form action=\"$start_page\" method=\"post\">"
                        cat "$tmp_dir/form_output"
                        echo "              <input type=\"hidden\" name=\"user\" value=\"$user\">"
                        echo "              <input type=\"hidden\" name=\"operation\" value=\"$operation\"></td></tr>"
                        echo "              <p>"
                        echo "              <input type=\"submit\" name=\"submit\" value=\"$submit_permission_add\">"
                        test $erase_option && echo "              <input type=\"submit\" name=\"submit\" value=\"$submit_permission_erase\">"
                        echo "              </p>"
                        echo "          </form>"
                        echo "      </p>"
                        ;;

                    "$submit_permission_add")

                        # Formulário de permissão.
                        echo "      <p>"
                        echo "          Editando permissões para o usuário '$user'<br>"
                        echo "          <form action=\"$start_page\" method=\"post\">"
                        # Tipo de recurso
                        echo "              <p>"
                        echo "                  Tipo de recurso:<br>"
                        echo "      		    <select class=\"select_default\" name=\"resource_type\">"
                        mklist "$regex_resource_type" | while read resource_type; do
                            echo "		        	<option>$resource_type</option>"
                        done
                        echo "		            </select>"
                        echo "              </p>"
                        # Nome do recurso
                        echo "              <p>"
                        echo "                  Nome do recurso:<br>"
                        echo "                  <input type=\"text\" class=\"text_default\" name=\"resource_name\"></input>"
                        echo "              </p>"
                        # Permissão
                        echo "              <p>"
                        echo "                  Permissão:<br>"
                        echo "      		    <select class=\"select_default\" name=\"permission\">"
                        mklist "$regex_permission" | while read permission; do
                            echo "		        	<option>$permission</option>"
                        done
                        echo "		            </select>"
                        echo "              </p>"
                        echo "              <input type=\"hidden\" name=\"user\" value=\"$user\">"
                        echo "              <input type=\"hidden\" name=\"operation\" value=\"$operation\">"
                        echo "              <input type=\"submit\" name=\"submit\" value=\"$submit_permission_save\">"
                        echo "          </form>"
                        echo "      </p>"
                        ;;

                    "$submit_permission_save")

                        resource_type="$(echo "$arg_string" | sed -rn "s/^.*&resource_type=([^\&]+)&.*$/\1/p")"
                        resource_name="$(echo "$arg_string" | sed -rn "s/^.*&resource_name=([^\&]+)&.*$/\1/p")"
                        permission="$(echo "$arg_string" | sed -rn "s/^.*&permission=([^\&]+)&.*$/\1/p")"
                        add_permission "user" "$user" "$resource_type" "$resource_name" "$permission" || end 1
                        echo "      <p><b>Permissão adicionada com sucesso para o usuário '$user'.</b></p>"
                        ;;

                    "$submit_permission_erase")

                        permission_string="$(echo "$arg_string" | sed -rn "s/^.*&permission_string=([^\&]+)&.*$/\1/p")"

                        while [ -n "$permission_string" ]; do
                            subject_type="$(echo "$permission_string" | cut -f1 -d ":")"
                            subject_name="$(echo "$permission_string" | cut -f2 -d ":")"
                            resource_type="$(echo "$permission_string" | cut -f3 -d ":")"
                            resource_name="$(echo "$permission_string" | cut -f4 -d ":")"
                            permission="$(echo "$permission_string" | cut -f5 -d ":")"

                            delete_permission "$subject_type" "$subject_name" "$resource_type" "$resource_name" "$permission" || end 1
                            echo "      <p>Permissão '$resource_type;$resource_name;$permission' removida para o usuário '$user'.</p>"

                            arg_string="$(echo "$arg_string" | sed -r "s/&permission_string=$permission_string//")"
                            permission_string="$(echo "$arg_string" | sed -rn "s/^.*&permission_string=([^\&]+)&.*$/\1/p")"

                        done

                        echo "      <p></b>Permissões selecionadas removidas com sucesso.</b></p>"
                        ;;
                esac
                ;;
        esac

    fi

fi

end 0