#!/bin/bash

# Funções comuns do servidor

function parse_multipart_form() { #argumentos: nome de arquivo com conteúdo do POST

    #atribui variáveis do formulário e prepara arquivos carregados para o servidor

    local boundary="$(echo "$CONTENT_TYPE" | sed -r "s|multipart/form-data; +boundary=||" | sed -r 's|\-|\\-|g')"
    local part_boundary="\-\-$boundary"
    local end_boundary="\-\-$boundary\-\-"
    local next_boundary=''
    local input_file="$1"
    local input_size="$(cat "$input_file" | wc -l)"
    local file_begin=''
    local file_end=''
    local file_name=''
    local var_name=''
    local var_set=false
    local i=0

    while [ "$i" -lt "$input_size" ]; do

        ((i++))
        line="$(sed -n "${i}p" "$input_file" | sed -r "s|[\$\`\(\)\{\}\<\>\~\*\r&']||g")"

        if echo "$line" | grep -Ex "$part_boundary|$end_boundary" > /dev/null; then
            file_name=''
            file_begin=''
            file_end=''
            var_name=''
            var_set=false

        elif echo "$line" | grep -Ex "Content\-Disposition: form\-data; name=\"[a-zA-Z0-9_]+\"; filename=\"[^\"]+\"" > /dev/null; then
            var_name="$(echo "$line" | sed -rn "s|Content\-Disposition: form\-data; name=([^;]+); filename=.+|\1|p" | sed -r "s|\"||g")"
            file_name="$(echo "$line" | sed -rn "s|Content\-Disposition: form\-data; name=[^;]+; filename=\"([a-zA-Z0-9][a-zA-Z0-9\._-]*)\"|\1|p")"
            test -n "$var_name" && test -n "$file_name" && eval "$var_name=$tmp_dir/$file_name" && var_set=true
            file_begin=$((i+3)) #i+1: content-type, i+2: '', i+3: file_begin
            next_boundary=$(sed -n "${file_begin},${input_size}p" "$input_file" | cat -t | grep -En "^$part_boundary" | head -n 1 | cut -d ':' -f1)
            next_boundary=$((next_boundary+file_begin-1))
            file_end=$((next_boundary-1))
            $var_set && sed -n "${file_begin},$((file_end-1))p" "$input_file" > "$tmp_dir/$file_name" && sed -rn "${file_end}s|\r$||p" "$input_file" | tr -d '\n' >> "$tmp_dir/$file_name"
            i="$file_end"

        elif echo "$line" | grep -Ex "Content\-Disposition: form\-data; name=\"[a-zA-Z0-9_]+\"" > /dev/null; then
            var_name="$(echo "$line" | sed -r "s|Content\-Disposition: form\-data; name=||" | sed -r "s|\"||g")"

        elif echo "$line" | grep -Ex "[a-zA-Z0-9\._/ -]+" > /dev/null ; then
            ! $var_set && test -n "$var_name" && eval "$var_name='$line'" && var_set=true

        fi

    done

}

function web_filter() {   # Filtra o input de formulários cgi

    set -f

    # Decodifica caracteres necessários,
    # Remove demais caracteres especiais,
    # Realiza substituições auxiliares

    echo "$1" | \
        sed -r 's|%C3%80|À|g' | \
        sed -r 's|%C3%81|Á|g' | \
        sed -r 's|%C3%82|Â|g' | \
        sed -r 's|%C3%83|Ã|g' | \
        sed -r 's|%C3%84|Ä|g' | \
        sed -r 's|%C3%85|Å|g' | \
        sed -r 's|%C3%86|Æ|g' | \
        sed -r 's|%C3%87|Ç|g' | \
        sed -r 's|%C3%88|È|g' | \
        sed -r 's|%C3%89|É|g' | \
        sed -r 's|%C3%8A|Ê|g' | \
        sed -r 's|%C3%8B|Ë|g' | \
        sed -r 's|%C3%8C|Ì|g' | \
        sed -r 's|%C3%8D|Í|g' | \
        sed -r 's|%C3%8E|Î|g' | \
        sed -r 's|%C3%8F|Ï|g' | \
        sed -r 's|%C3%90|Ð|g' | \
        sed -r 's|%C3%91|Ñ|g' | \
        sed -r 's|%C3%92|Ò|g' | \
        sed -r 's|%C3%93|Ó|g' | \
        sed -r 's|%C3%94|Ô|g' | \
        sed -r 's|%C3%95|Õ|g' | \
        sed -r 's|%C3%96|Ö|g' | \
        sed -r 's|%C3%97|×|g' | \
        sed -r 's|%C3%98|Ø|g' | \
        sed -r 's|%C3%99|Ù|g' | \
        sed -r 's|%C3%9A|Ú|g' | \
        sed -r 's|%C3%9B|Û|g' | \
        sed -r 's|%C3%9C|Ü|g' | \
        sed -r 's|%C3%9D|Ý|g' | \
        sed -r 's|%C3%9E|Þ|g' | \
        sed -r 's|%C3%9F|ß|g' | \
        sed -r 's|%C3%A0|à|g' | \
        sed -r 's|%C3%A1|á|g' | \
        sed -r 's|%C3%A2|â|g' | \
        sed -r 's|%C3%A3|ã|g' | \
        sed -r 's|%C3%A4|ä|g' | \
        sed -r 's|%C3%A5|å|g' | \
        sed -r 's|%C3%A6|æ|g' | \
        sed -r 's|%C3%A7|ç|g' | \
        sed -r 's|%C3%A8|è|g' | \
        sed -r 's|%C3%A9|é|g' | \
        sed -r 's|%C3%AA|ê|g' | \
        sed -r 's|%C3%AB|ë|g' | \
        sed -r 's|%C3%AC|ì|g' | \
        sed -r 's|%C3%AD|í|g' | \
        sed -r 's|%C3%AE|î|g' | \
        sed -r 's|%C3%AF|ï|g' | \
        sed -r 's|%C3%B0|ð|g' | \
        sed -r 's|%C3%B1|ñ|g' | \
        sed -r 's|%C3%B2|ò|g' | \
        sed -r 's|%C3%B3|ó|g' | \
        sed -r 's|%C3%B4|ô|g' | \
        sed -r 's|%C3%B5|õ|g' | \
        sed -r 's|%C3%B6|ö|g' | \
        sed -r 's|%C3%B7|÷|g' | \
        sed -r 's|%C3%B8|ø|g' | \
        sed -r 's|%C3%B9|ù|g' | \
        sed -r 's|%C3%BA|ú|g' | \
        sed -r 's|%C3%BB|û|g' | \
        sed -r 's|%C3%BC|ü|g' | \
        sed -r 's|%C3%BD|ý|g' | \
        sed -r 's|%C3%BE|þ|g' | \
        sed -r 's|%C3%BF|ÿ|g' | \
        sed -r 's|\+| |g' | \
        sed -r 's|%21|\!|g' | \
        sed -r 's|%24|\$|g' | \
        sed -r 's|%25|::percent::|g' | \
        sed -r 's|%2C|,|g' | \
        sed -r 's|%2F|/|g' | \
        sed -r 's|%3A|\:|g' | \
        sed -r 's|%3D|=|g' | \
        sed -r 's|%40|@|g' | \
        sed -r 's|%5B|\[|g' | \
        sed -r 's|%5D|\]|g' | \
        sed -r 's|%..||g' | \
        sed -r 's|\*||g' | \
        sed -r 's|::percent::|%|g' | \
        sed -r 's| +| |g' | \
        sed -r 's| $||g'

    set +f

}

function web_links () {

    mklist "$cgi_admin_pages" > $tmp_dir/cgi_admin_pages
    mklist "$cgi_search_pages" > $tmp_dir/cgi_search_pages
    mklist "$cgi_deploy_pages" > $tmp_dir/cgi_deploy_pages
    mklist "$cgi_log_pages" > $tmp_dir/cgi_log_pages
    mklist "$cgi_help_pages" > $tmp_dir/cgi_help_pages
    mklist "$cgi_account_pages" > $tmp_dir/cgi_account_pages
    
    local categories=([0]='admin' [1]='search' [2]='deploy' [3]='log' [4]='help' [5]='account')
    local category_titles=([0]='Administração' [1]='Pesquisa' [2]='Deploy' [3]='Logs' [4]='Ajuda' [5]="${REMOTE_USER:-Conta}")
    local category=''
    local category_title=''
    local count=0
    local index=0
    local link_name=''
    local link_url=''
    local link_title=''
    
    echo "      <div id=\"header_links\">"

    for category in ${categories[@]}; do

        category_title=${category_titles[$index]}
        count=$(cat $tmp_dir/cgi_${category}_pages | wc -l)
        
        case $count in

            0) 
                continue
                ;;

            1)  
                link_name="$(cat $tmp_dir/cgi_${category}_pages)"
                link_uri="$(dirname $SCRIPT_NAME)/$link_name.cgi"
                link_title="$(eval "echo \$cgi_${link_name}_title")"
                echo "<div class=\"header_button\"><a href=\"$link_uri\">"$link_title"</a></div>"
                ;;

            *)
                echo "<div class=\"dropdown\">"
                echo "  <div class=\"header_button\">$category_title &#9660;</div>"
                echo "  <div class=\"dropdown_content\">"
                cat $tmp_dir/cgi_${category}_pages | while read link_name; do
                    link_uri="$(dirname $SCRIPT_NAME)/$link_name.cgi"
                    link_title="$(eval "echo \$cgi_${link_name}_title")"
                    echo "      <a href=\"$link_uri\">$link_title</a>"
                done
                echo "  </div>"
                echo "</div>"
                ;;
        
        esac

        ((index++))

    done

    echo "      </div>"

    return 0

}

function web_header () {

    test "$(basename $SCRIPT_NAME)" == 'index.cgi' && start_page="$(dirname $SCRIPT_NAME)/" || start_page="$SCRIPT_NAME"
    release_name=$(cat $release_file 2> /dev/null || echo "")
    page_name=$(basename $SCRIPT_NAME | cut -f1 -d '.')
    page_title="$(eval "echo \$cgi_${page_name}_title")"

    echo 'Content-type: text/html'
    echo ''
    echo '<!DOCTYPE html>'
    echo '<html>'
    echo '  <head>'
    echo '      <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">'
    echo '      <meta http-equiv="X-UA-Compatible" content="IE=edge">'
    echo "      <title>$web_app_name $release_name : $page_title</title>"
    echo "      <link rel=\"stylesheet\" type=\"text/css\" href=\"$apache_css_alias/default.css\">"
    echo '  </head>'
    echo "  <body>"
    echo "      <div id=\"header\">"
    echo "          <div id=\"title\"><b><a href="$web_context_path">$web_app_name</a> /</b> $page_title</div>"
    web_links
    echo "      </div>"
    echo "      <div id=\"main\">"

    return 0
}

function web_tr_pagination () {

    local table_content="$1"
    local header_line="$2"
    local data_size
    local view_size
    local print_size
    local arg_delimiter='&'
    local page
    local min_page
    local max_page
    local next
    local prev
    local first_uri
    local next_uri
    local prev_uri
    local last_uri
    local nav
    local no_results_msg='<tr><td colspan="100">Nenhum registro encontrado.</td></tr>'

    test "$#" -eq "2" || { echo "web_tr_pagination(): favor informar dois argumentos." ; return 1 ; }
    test -f "$table_content" || { echo "web_tr_pagination(): o primeiro argumento deve ser um arquivo." ; return 1 ; }
    test "$header_line" -ge "0" 2> /dev/null || { echo "web_tr_pagination(): o segundo argumento deve ser o número da linha de cabeçalho." ; return 1 ; }
    test -z "$QUERY_STRING" && arg_delimiter='?'

    data_size=$(($(cat "$table_content" | wc -l)-$header_line))
    view_size=$(echo "$arg_string" | sed -rn "s/^.*&n=([^\&]+)&.*$/\1/p")
    test -z "$view_size" && view_size="$cgi_table_size"

    min_page=1
    max_page=$(($data_size/$view_size))
    test $(($max_page*$view_size)) -lt $data_size && ((max_page++))

    page=$(echo "$arg_string" | sed -rn "s/^.*&p=([^\&]+)&.*$/\1/p")
    test -z "$page" && page=1
    next=$(($page+1))
    prev=$(($page-1))

    first_uri="$(echo "$REQUEST_URI" | sed -rn "s/^(.*[&\?]p=)$page(.*)$/\1$min_page\2/p")"
    test -z "$first_uri" && first_uri="$REQUEST_URI${arg_delimiter}p=$min_page"

    prev_uri="$(echo "$REQUEST_URI" | sed -rn "s/^(.*[&\?]p=)$page(.*)$/\1$prev\2/p")"
    test -z "$prev_uri" && prev_uri="$REQUEST_URI${arg_delimiter}p=$prev"

    next_uri="$(echo "$REQUEST_URI" | sed -rn "s/^(.*[&\?]p=)$page(.*)$/\1$next\2/p")"
    test -z "$next_uri" && next_uri="$REQUEST_URI${arg_delimiter}p=$next"

    last_uri="$(echo "$REQUEST_URI" | sed -rn "s/^(.*[&\?]p=)$page(.*)$/\1$max_page\2/p")"
    test -z "$last_uri" && last_uri="$REQUEST_URI${arg_delimiter}p=$max_page"

    # define comando de exibição das linhas
    test $page -eq $max_page && print_size=$(($view_size-($view_size*$max_page-$data_size))) || print_size=$view_size
    test $data_size -ge 1 && print_page_cmd="head -n '$((($page*$view_size)+$header_line))' '$table_content' | tail -n '$print_size'" || print_page_cmd="echo '$no_results_msg'"

    # define links para navegação
    nav="Página $page"
    test $prev -ge $min_page && nav="<a href=\"$first_uri\"><button type=\"button\">&lt;&lt;</button></a> <a href=\"$prev_uri\"><button type=\"button\">&lt;</button></a> $nav"
    test $next -le $max_page && nav="$nav <a href=\"$next_uri\"><button type=\"button\">&gt;</button></a> <a href=\"$last_uri\"><button type=\"button\">&gt;&gt;</button></a>"
    nav_right="<div id=\"nav_right\">$nav</div>"

}

function web_query_history () {

    file=$history_dir/$history_csv_file

    if [ -f "$file" ]; then

        export 'SELECT' 'DISTINCT' 'TOP' 'WHERE' 'ORDERBY'
        table_content="$tmp_dir/html_table"
        $install_dir/cgi/table_data.cgi $file > $table_content
        web_tr_pagination "$table_content" "1"

        echo "      <p>"
        echo "          <table class=\"stripped_table\">"
        head -n 1 "$table_content"
        eval "$print_page_cmd"
        echo "          </table>"
        echo "      </p>"

    else
        echo "<p>Arquivo de histórico inexistente</p>"
    fi

    return 0
}

function web_footer () {

    echo "          <div id=\"navbar\">"
    echo "              <div id=\"nav_left\">"
    echo "                  <a href=\"$start_page\">Início</a>"
    echo "              </div>"
    echo "              $nav_right"
    echo "          </div>"
    echo "      </div>"
    echo "      <div class=\"spacer\"></div>"
    echo "      <div id=\"footer\">Versão: $release_name</div>"
    echo '  </body>'
    echo '</html>'

    return 0

}

function content_loading() {

    echo "          <div id=\"loading-container\">"
    echo "              <div id=\"loading-1\"></div>"
    echo "              <div id=\"loading-2\"></div>"
    echo "              <div id=\"loading-3\"></div>"
    echo "              <div id=\"loading-4\"></div>"
    echo "              <div id=\"loading-5\"></div>"
    echo "          </div>"
    return 0

}

function content_ready() {

    echo "          <div id=\"loading-hide\"></div>"
    return 0

}

function add_login() {

    test -w "$web_users_file" || return 1

    if [ -n "$1" ] && [ -n "$2" ]; then
        local user="$1"
        local password="$2"
        local error=false
        cp -f "$web_users_file" "$web_users_file.bak" || return 1
        htpasswd -b "$web_users_file" "$user" "$password" || error=true
        $error && cp -f "$web_users_file.bak" "$web_users_file" && return 1
    else
        return 1
    fi

    return 0

}

function delete_login() {

    test -w "$web_users_file" || return 1

    if [ -n "$1" ]; then
        local user="$1"
        local error=false
        cp -f "$web_users_file" "$web_users_file.bak" || return 1
        htpasswd -D "$web_users_file" "$user" || error=true
        $error && cp -f "$web_users_file.bak" "$web_users_file" && return 1
    else
        return 1
    fi

    return 0

}

function delete_email() {

    test -w "$web_emails_file" || return 1

    if [ -n "$1" ]; then
        local user_regex="$(echo "$1" | sed -r 's|([\.\-])|\\\1|g' )"
        local error=false
        cp -f "$web_emails_file" "$web_emails_file.bak" || return 1
        sed -i.bak -r "/^$user_regex:.*$/d" "$web_emails_file" || error=true
        $error && cp -f "$web_emails_file.bak" "$web_emails_file" && return 1
    else
        return 1
    fi

    return 0

}

function add_email() {

    test -w "$web_emails_file" || return 1

    if [ -n "$1" ] && [ -n "$2" ]; then
        local user="$1"
        local email="$2"
        local error=false
        cp -f "$web_emails_file" "$web_emails_file.bak" || return 1
        echo "$user:$email" >> "$web_emails_file" || error=true
        $error && cp -f "$web_users_file.bak" "$web_users_file" && return 1
    else
        return 1
    fi

    return 0

}

function get_email() {

    test -w "$web_emails_file" || return 1

    if [ -n "$1" ]; then
        local user_regex="$(echo "$1" | sed -r 's|([\.\-])|\\\1|g' )"
        grep -E "^$user_regex:[[:blank:]]*[[:graph:]]+[[:blank:]]*$" "$web_emails_file" > /dev/null || return 1
        sed -rn "s/^$user_regex:[[:blank:]]*([[:graph:]]+)[[:blank:]]*$/\1/p" "$web_emails_file" | tail -n 1
    else
        return 1
    fi

    return 0

}

function add_group() {

    test -w "$web_groups_file" || return 1

    if [ -n "$1" ]; then
        local group="$1"
        local error=false
        cp -f "$web_groups_file" "$web_groups_file.bak" || return 1
        echo "$group:" >> "$web_groups_file" || error=true
        $error && cp -f "$web_groups_file.bak" "$web_groups_file" && return 1
    else
        return 1
    fi

    return 0

}

function delete_group() {

    test -w "$web_groups_file" || return 1

    if [ -n "$1" ]; then
        local group="$1"
        local error=false
        local delete_regex="^$(echo "$group" | sed -r 's|([\.\-])|\\\1|g'):.*\$"
        cp -f "$web_groups_file" "$web_groups_file.bak" || return 1
        sed -i.bak -r "/$delete_regex/d" "$web_groups_file" || error=true
        $error && cp -f "$web_groups_file.bak" "$web_groups_file" && return 1
    else
        return 1
    fi

    return 0

}

function membership() {

    if [ -n "$1" ]; then
        local user_regex="$(echo "$1" | sed -r 's|([\.\-])|\\\1|g' )"
        grep -Ex "[^:]+:.* +$user_regex +.*|[^:]+:$user_regex +.*|[^:]+:.* +$user_regex|[^:]+:$user_regex" "$web_groups_file" | cut -f1 -d ':'
    else
        return 1
    fi

    return 0

}

function members_of() {

    if [ -n "$1" ]; then
        local group_regex="$(echo "$1" | sed -r 's|([\.\-])|\\\1|g' )"
        local members="$(grep -Ex "$group_regex:.*" "$web_groups_file" | cut -f2 -d ':' | sed -r 's|^ +||' | sed -r 's| +$||')"
        test -n "$members" && mklist "$members"
    else
        return 1
    fi

    return 0

}

function unsubscribe() {

    test -w "$web_groups_file" || return 1

    if [ -n "$1" ] && [ -n "$2" ]; then
        local user_regex="$(echo "$1" | sed -r 's|([\.\-])|\\\1|g' )"
        local group_regex="$(echo "$2" | sed -r 's|([\.\-])|\\\1|g' )"
        local error=false
        cp -f "$web_groups_file" "$web_groups_file.bak" || return 1
        sed -i.bak -r "s/^($group_regex:.* +)($user_regex +)(.*)$/\1\3/" "$web_groups_file" || error=true
        sed -i.bak -r "s/^($group_regex:)($user_regex +)(.*)$/\1\3/" "$web_groups_file" || error=true
        sed -i.bak -r "s/^($group_regex:.* +)($user_regex)$/\1/" "$web_groups_file" || error=true
        sed -i.bak -r "s/^($group_regex:)($user_regex)$/\1/" "$web_groups_file" || error=true
        $error && cp -f "$web_groups_file.bak" "$web_groups_file" && return 1
    else
        return 1
    fi

    return 0

}

function subscribe() {

    test -w "$web_groups_file" || return 1

    if [ -n "$1" ] && [ -n "$2" ]; then
        local user="$1"
        local group_regex="$(echo "$2" | sed -r 's|([\.\-])|\\\1|g' )"
        local error=false
        cp -f "$web_groups_file" "$web_groups_file.bak" || return 1
        sed -i.bak -r "s/^($group_regex:.*)$/\1 $user/" "$web_groups_file" || error=true
        $error && cp -f "$web_groups_file.bak" "$web_groups_file" && return 1
    else
        return 1
    fi

    return 0

}

function chk_permission() { #subject_type (user/group), #subject_name, #resource_type, #resource_name, #permission (read/write)

    test -f "$web_permissions_file" || return 1
    test "$#" -eq 5 || return 1

    local subject_type="$1"
    local subject_name="$2"
    local resource_type="$3"
    local resource_name="$4"
    local permission="$5"

    valid "$subject_type" "subject_type" "Erro. 'subject_type': '$subject_type'.<br>" || return 1
    valid "$subject_name" "subject_name" "Erro. 'subject_name': '$subject_name'.<br>" || return 1
    valid "$resource_type" "resource_type" "Erro. 'resource_type': '$resource_type'.<br>" || return 1
    valid "$resource_name" "resource_name" "Erro. 'resource_name': '$resource_name'.<br>" || return 1
    valid "$permission" "permission" "Erro. 'permission': '$permission'.<br>" || return 1

    return 0

}

function add_permission() { #subject_type (user/group), #subject_name, #resource_type, #resource_name, #permission (read/write)

    chk_permission $@ || return 1
    test -w "$web_permissions_file" || return 1
    cp -f "$web_permissions_file" "$web_permissions_file.bak" || return 1
    local error=false

    if [ "$(cat $web_permissions_file | wc -l)" -eq 0 ]; then
        local header="$(echo "${col[subject_type]}${col[subject_name]}${col[resource_type]}${col[resource_name]}${col[permission]}" | sed -r 's/\[//g' | sed -r "s/\]/$delim/g")"
        echo "$header" >> "$web_permissions_file" || error=true
        $error && cp -f "$web_permissions_file.bak" "$web_permissions_file" && return 1
    fi

    if grep -Ex "$1$delim$2$delim$3$delim$4$delim(${regex[permission]})$delim" "$web_permissions_file" > /dev/null; then
        echo "<p>Já foi atribuída uma permissão correspondente ao sujeito '$2' / recurso '$4'. Favor remover a permissão conflitante e tentar novamente.</p>"
        return 1
    else
        echo "$1$delim$2$delim$3$delim$4$delim$5$delim" >> "$web_permissions_file" || error=true
        $error && cp -f "$web_permissions_file.bak" "$web_permissions_file" && return 1
    fi

    return 0

}

function delete_permission() { #subject_type (user/group), #subject_name, #resource_type, #resource_name, #permission (read/write)

    chk_permission $@ || return 1
    test -w "$web_permissions_file" || return 1
    cp -f "$web_permissions_file" "$web_permissions_file.bak" || return 1
    local error=false
    local delete_regex="^$(echo "$1$delim$2$delim$3$delim$4$delim$5$delim" | sed -r 's|([\.\-])|\\\1|g')\$"
    sed -i.bak -r "/$delete_regex/d" "$web_permissions_file" || error=true
    $error && cp -f "$web_permissions_file.bak" "$web_permissions_file" && return 1

    return 0

}

function clearance() { #subject_type (user/group), #subject_name, #resource_type, #resource_name, #permission (read/write)

    test "$1" == "user" || return 1
    test "$#" -eq "5" || return 1
    chk_permission "$1" "$2" "$3" "$4" "$5" || return 1
    membership "$2" | grep -Ex "admin" > /dev/null && return 0

    local groups_regex=''
    local groups_permissions=''
    local permission="$5"
    local effective="$(query_file.sh -d "$delim" -r "" -x 1 -s 5 -t 1 -f $web_permissions_file -w 1=="user" 2=="$2" 3=="$3" 4=="$4")" || return 1

    if [ -z "$effective" ]; then
        groups_regex="($(membership "$2" | tr "\n" "|" | sed -r 's|([\.\-])|\\\1|g' | sed -r "s/\|$//"))"
        groups_permissions="$(query_file.sh -d "$delim" -r "" -x 1 -s 5 -u -f $web_permissions_file -w 1=="group" 2=~"$groups_regex" 3=="$3" 4=="$4" -o 5 asc)"
        if [ -n "$groups_permissions" ]; then
            echo "$groups_permissions" | grep -Ex "read.*" > /dev/null && effective="read" || effective="write"
        fi
    fi

    test "$effective" = "write" && return 0
    test "$effective" = "$permission" && return 0
    return 1

}

function editconf () {      # Atualiza entrada em arquivo de configuração

    local param="$1"
    local match="$(echo "$param" | sed -r 's#(\[|\])#\\&#g' )"
    local value="$2"
    local file="$3"
    local error=false
    local message="Erro. Não foi possível editar o arquivo de configuração."

    test -n "$param" || error=true
    test -n "$file" || error=true
    touch "$file" || error=true
    $error && echo "$message" && return 1

    if [ $(grep -Ex "$match=.*" "$file" | wc -l) -ne 1 ]; then
        sed -i -r "/^$match=.*$/d" "$file"
        echo "$param='$value'" >> "$file"
    else
        grep -Ex "$match=('$value'|\"$value\")" "$file" > /dev/null
        test "$?" -eq 1 && sed -i -r "s|^($match=).*$|\1\'$value\'|" "$file"
    fi

    return 0
}
