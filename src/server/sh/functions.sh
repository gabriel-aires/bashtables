#!/bin/bash

# Funções comuns do servidor

function web_filter() {   # Filtra o input de formulários cgi

    set -f

    # Decodifica caracteres necessários,
    # Remove demais caracteres especiais,
    # Realiza substituições auxiliares

    echo "$1" | \
        sed -r 's|\+| |g' | \
        sed -r 's|%21|\!|g' | \
        sed -r 's|%25|::percent::|g' | \
        sed -r 's|%2C|,|g' | \
        sed -r 's|%2F|/|g' | \
        sed -r 's|%3A|\:|g' | \
        sed -r 's|%3D|=|g' | \
        sed -r 's|%40|@|g' | \
        sed -r 's|%..||g' | \
        sed -r 's|\*||g' | \
        sed -r 's|::percent::|%|g' | \
        sed -r 's| +| |g' | \
        sed -r 's| $||g'

    set +f

}

function web_header () {

    test "$(basename $SCRIPT_NAME)" == 'index.cgi' && start_page="$(dirname $SCRIPT_NAME)/" || start_page="$SCRIPT_NAME"
    page_name=$(basename $SCRIPT_NAME | cut -f1 -d '.')
    page_title="$(eval "echo \$cgi_${page_name}_title")"

    echo 'Content-type: text/html'
    echo ''
    echo '<html>'
    echo '  <head>'
    echo '      <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">'
    echo "      <title>$page_title</title>"
    echo "      <link rel=\"stylesheet\" type=\"text/css\" href=\"$apache_css_alias/default.css\">"
    echo '  </head>'
    echo "  <body>"
    echo "      <div id=\"header\" class=\"header_color\">$page_title</div>"
    echo "      <div id=\"main\">"

    return 0
}

function web_query_history () {

    file=$history_dir/$history_csv_file

    if [ -f "$file" ]; then

        export 'SELECT' 'DISTINCT' 'TOP' 'WHERE' 'ORDERBY'
        table_content="$tmp_dir/html_table"
        $install_dir/cgi/table_data.cgi $file > $table_content

        if [ -z "$QUERY_STRING" ]; then
            view_size="$cgi_table_size"
            page=1
            next=2
            prev=0
            next_uri="$start_page?p=$next"
        else
            view_size=$(echo "$arg_string" | sed -rn "s/^.*&n=([^\&]+)&.*$/\1/p")
            test -z "$view_size" && view_size="$cgi_table_size"

            page=$(echo "$arg_string" | sed -rn "s/^.*&p=([^\&]+)&.*$/\1/p")
            test -z "$page" && page=1

            next=$(($page+1))
            prev=$(($page-1))

            next_uri="$(echo "$REQUEST_URI" | sed -rn "s/^(.*[&\?]p=)$page(.*)$/\1$next\2/p")"
            test -z "$next_uri" && next_uri="$REQUEST_URI&p=$next"

            prev_uri="$(echo "$REQUEST_URI" | sed -rn "s/^(.*[&\?]p=)$page(.*)$/\1$prev\2/p")"
            test -z "$prev_uri" && prev_uri="$REQUEST_URI&p=$prev"
        fi

        data_size=$(($(cat "$table_content" | wc -l)-1))
        min_page=1
        max_page=$(($data_size/$view_size))
        test $(($max_page*$view_size)) -lt $data_size && ((max_page++))
        test $page -eq $max_page && print_size=$(($view_size-($view_size*$max_page-$data_size))) || print_size=$view_size
        nav="$page"

        if [ $next -le $max_page ]; then
            nav="$nav <a href=\"$next_uri\">$next</a>"
        fi

        if [ $prev -ge $min_page ]; then
            nav="<a href=\"$prev_uri\">$prev</a> $nav"
        fi

        echo "      <p>"
        echo "          <table class=\"query_table\">"
        head -n 1 "$table_content"
        test $data_size -ge 1 && head -n $((($page*$view_size)+1)) "$table_content" | tail -n "$print_size" || echo "<tr><td colspan=\"100\">Nenhum registro encontrado.</td></tr>"
        echo "          </table>"
        echo "      </p>"

        navbar="<div id=\"navbar\"><p>Página: $nav</p></div>"

    else

        echo "<p>Arquivo de histórico inexistente</p>"

    fi

    return 0
}

function web_footer () {

    mklist "$cgi_list_pages" $tmp_dir/cgi_list_pages

    echo "      <hr>"
    echo "      <div class=\"footer\">"
    echo "          <div id=\"links\">"
    echo "              <p><a href=\"$start_page\">Início</a></p>"
    while read link_name; do
        link_uri="$(dirname $SCRIPT_NAME)/$link_name.cgi"
        link_title="$(eval "echo \$cgi_${link_name}_title")"
        test "$SCRIPT_NAME" != "$link_uri" && echo "          <p><a href=\"$link_uri\">"$link_title"</a></p>"
    done < $tmp_dir/cgi_list_pages
    echo "              <p><a href=\"$apache_log_alias\">Logs</a></p>"
    echo "          </div>"
    echo "          $navbar"
    echo "      </div>"
    echo "  </div>"

    return 0

}

function editconf () {      # Atualiza entrada em arquivo de configuração

    local exit_cmd="end 1 2> /dev/null || exit 1"
    local campo="$1"
    local valor_campo="$2"
    local arquivo_conf="$3"

    if [ -n "$campo" ] && [ -n "$arquivo_conf" ]; then

        touch $arquivo_conf || eval "$exit_cmd"

        if [ $(grep -Ex "^$campo\=.*$" $arquivo_conf | wc -l) -ne 1 ]; then
            sed -i -r "/^$campo\=.*$/d" "$arquivo_conf"
            echo "$campo='$valor_campo'" >> "$arquivo_conf"
        else
            grep -Ex "$campo='$valor_campo'|$campo=\"$valor_campo\"" "$arquivo_conf" > /dev/null
            test "$?" -eq 1 && sed -i -r "s|^($campo\=).*$|\1\'$valor_campo\'|" "$arquivo_conf"
        fi

    else
        echo "Erro. Não foi possível editar o arquivo de configuração." && $exit_cmd
    fi

}
