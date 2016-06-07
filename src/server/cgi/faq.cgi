#!/bin/bash

### Inicialização
source $(dirname $(dirname $(dirname $(readlink -f $0))))/common/sh/include.sh || exit 1
source $install_dir/sh/include.sh || exit 1

function end() {
    test "$1" == "0" || echo "      <p><b>Operação inválida.</b></p>"
    echo "</div>"
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

function display_faq() {

    test -f $tmp_dir/results || return 1

    local error=0
    local content_file="$(head -n 1 $tmp_dir/results | sed -r "s|^([^;]*);([^;]*);([^;]*);[^;]*;$|\1\%\2\%\3\%|")"

    sed -i -r "s|^$faq_dir_tree/||" $tmp_dir/results
    sed -i -r "s|^([^;]*);([^;]*);([^;]*);([^;]*);$|<a_href=\"$start_page\?category=\1\&proceed=$proceed_search\">\1</a>;<a_href=\"$start_page\?category=\1\&question=\2\&proceed=$proceed_view\">\4</a>;\3;|" $tmp_dir/results

    while grep -Ex "([^;]*;){2}(<a_href.*/a> )?$regex_faq_tag [^;]*;" $tmp_dir/results > /dev/null; do
        sed -i -r "s|^(([^;]*;){2}(<a_href.*/a> )?)($regex_faq_tag) ([^;]*;)$|\1<a_href=\"$start_page\?tag=\4\&proceed=$proceed_search\">\4</a> \5|" $tmp_dir/results
    done

    sed -i -r "s|^(([^;]*;){2}(<a_href.*/a> )?)($regex_faq_tag);$|\1<a_href=\"$start_page\?tag=\4\&proceed=$proceed_search\">\4</a>;|" $tmp_dir/results

    while grep -E "<a_href=\"$start_page\?[^\"]*/[^\"]*\">" $tmp_dir/results > /dev/null; do
        sed -i -r "s|(<a_href=\"$start_page\?[^\"]*)/([^\"]*\">)|\1\%2F\2|" $tmp_dir/results
    done

    sed -i -r "s|<a_href=|<a href=|g" $tmp_dir/results

    if [ $(cat $tmp_dir/results | wc -l) -eq 1 ]; then

        category_href="$(sed -r "s|^([^;]*);[^;]*;[^;]*;$|\1|" $tmp_dir/results)"
        tag_href="$(sed -r "s|^[^;]*;[^;]*;([^;]*);$|\1|" $tmp_dir/results)"

        echo "<h3>"
        head -n 1 "$content_file"
        echo "</h3>"
        echo "<div class=\"cfg_color\">"
        tail -n +2 "$content_file" | tr "\n" '<' | sed -r 's|<|<br>|g'
        echo "</div>"
        echo "<p><b>Categoria:</b> $category_href</p>"
        echo "<p><b>Tags:</b> $tag_href</p>"
        # Formulário de remoção
        if "$allow_edit"; then
            echo "          <form action=\"$start_page\" method=\"post\">"
            echo "              <p>"
            echo "                  <input type=\"hidden\" name=\"question_file\" value=\"$content_file\">"
            echo "                  <input type=\"submit\" name=\"proceed\" value=\"$proceed_remove\">"
            echo "              </p>"
            echo "          </form>"
        fi

    elif [ $(cat $tmp_dir/results | wc -l) -ge 2 ]; then

        sed -i -r "s|^([^;]*;)([^;]*;)([^;]*;)$|\2\1\3|" $tmp_dir/results
        sed -i -r "s|;|</td><td>|g" $tmp_dir/results
        sed -i -r "s|^(.)|<tr class=\"cfg_color\"><td width=80%>\1|" $tmp_dir/results
        sed -i -r "s|<td>$|</tr>|" $tmp_dir/results

        echo "<h3>Tópicos:</h3>"
        echo "<table id=\"faq\" width=100%>"
        echo "<tr class=\"header_color\"><td width=80%>Tópico</td><td>Categoria</td><td>Tags</td></tr>"
        cat $tmp_dir/results
        echo "</table>"

    else

        echo "<p>Sua busca não retornou resultados.</p>"
        error=1

    fi

    return "$error"

}

trap "end 1" SIGQUIT SIGINT SIGHUP
mkdir $tmp_dir

# Cabeçalho
web_header

test -d "$faq_dir_tree" || end 1

proceed_search="Buscar"
proceed_view="Exibir"
proceed_new="Novo"
proceed_remove="Remover"
show_edit=false
membership "$REMOTE_USER" | grep -Ex 'admin' > /dev/null && allow_edit=true

regex_faq_filename="[a-zA-Z0-9][a-zA-Z0-9\._-]*"
regex_faq_category="([a-z0-9]+/?)+"
regex_faq_tag="[a-zA-Z0-9\.-]+"
regex_faq_taglist="$regex_faq_tag( $regex_faq_tag)*"

# listas de tópicos, categorias e tags
find $faq_dir_tree/ -mindepth 2 -type f | xargs -I{} grep -m 1 -H ".*" {} | tr -d ":" | sed -r "s|(.)$|\1\%|"> $tmp_dir/questions.list
find $faq_dir_tree/ -mindepth 1 -type d | sed -r "s|^$faq_dir_tree/||" | sort > $tmp_dir/categories.list
cut -d '%' -f 3 $tmp_dir/questions.list | tr " " "\n" | sort | uniq > $tmp_dir/tags.list

# Sidebar
echo "      <div class=\"column_small\" id=\"faq_sidebar\">"

# Formulário de pesquisa
echo "          <h3>Busca:</h3>"
echo "          <form action=\"$start_page\" method=\"get\">"
echo "              <p>"
echo "                  <select class=\"select_large_percent\" name=\"category\">"
echo "                          <option value=\"\" selected>Categoria...</option>"
sed -r "s|(.*)|\t\t\t\t\t<option>\1</option>|" $tmp_dir/categories.list
echo "                  </select>"
echo "              </p>"
echo "              <p>"
echo "                  <select class=\"select_large_percent\" name=\"tag\">"
echo "                          <option value=\"\" selected>Tag...</option>"
sed -r "s|(.*)|\t\t\t\t\t<option>\1</option>|" $tmp_dir/tags.list
echo "                  </select>"
echo "              </p>"
echo "              <p>"
echo "                  <input type=\"text\" class=\"text_large_percent\" placeholder=\" Pesquisar...\" name=\"search\"></input>"
echo "              </p>"
echo "              <p>"
echo "                  <input type=\"submit\" name=\"proceed\" value=\"$proceed_search\">"
echo "              </p>"
echo "          </form>"

# Formulário de upload
if "$allow_edit"; then
    echo "          <br>"
    echo "          <h3>Adicionar:</h3>"
    echo "          <form action=\"$start_page\" method=\"post\" enctype=\"multipart/form-data\">"
    echo "              <p>"
    echo "                  <button type=\"button\" class=\"text_large_percent\"><label for=\"question_file\">Selecionar Arquivo...</label></button>"
    echo "                  <input type=\"file\" style=\"visibility: hidden\" id=\"question_file\" name=\"question_file\"></input>"
    echo "                  <input type=\"text\" class=\"text_large_percent\" placeholder=\" Categoria (obrigatório)\" name=\"category\"></input>"
    echo "              </p>"
    echo "              <p>"
    echo "                  <input type=\"text\" class=\"text_large_percent\" placeholder=\" Lista de tags\" name=\"tag\"></input>"
    echo "              </p>"
    echo "              <p>"
    echo "                  <input type=\"submit\" name=\"proceed\" value=\"$proceed_new\">"
    echo "              </p>"
    echo "          </form>"
fi

echo "      </div>"

parsed=false
var_string=false

if [ "$REQUEST_METHOD" == "POST" ]; then

    if [ "$CONTENT_TYPE" == "application/x-www-form-urlencoded" ]; then
        test -n "$CONTENT_LENGTH" && read -n "$CONTENT_LENGTH" POST_STRING
        var_string=true
        arg_string="&$(web_filter "$POST_STRING")&"

    elif echo "$CONTENT_TYPE" | grep -Ex "multipart/form-data; +boundary=.*" > /dev/null; then
        cat > "$tmp_dir/POST_CONTENT"
        parse_multipart_form "$tmp_dir/POST_CONTENT"
        rm -f "$tmp_dir/POST_CONTENT"
    fi

else
    var_string=true
    arg_string="&$(web_filter "$QUERY_STRING")&"
fi

if $var_string; then
    category=$(echo "$arg_string" | sed -rn "s/^.*&category=([^\&]+)&.*$/\1/p")
    tag=$(echo "$arg_string" | sed -rn "s/^.*&tag=([^\&]+)&.*$/\1/p")
    question=$(echo "$arg_string" | sed -rn "s/^.*&question=([^\&]+)&.*$/\1/p")
    question_file=$(echo "$arg_string" | sed -rn "s/^.*&question_file=([^\&]+)&.*$/\1/p")
    search=$(echo "$arg_string" | sed -rn "s/^.*&search=([^\&]+)&.*$/\1/p")
    proceed=$(echo "$arg_string" | sed -rn "s/^.*&proceed=([^\&]+)&.*$/\1/p")
fi

test -n "$proceed" && parsed=true

# Tópicos
echo "<div class=\"column_large\" id=\"faq_topics\">"

if ! $parsed; then

    query_file.sh -d "%" -r ";" -s 1 2 3 4 -f $tmp_dir/questions.list -o 1 4 asc > $tmp_dir/results
    display_faq

else

    case "$proceed" in

        "$proceed_search")

            where=''

            test -n "$search" && find $faq_dir_tree/ -mindepth 2 -type f | xargs -I{} grep -ilF "$search" {} | xargs -I{} grep -m 1 -H ".*" {} | tr -d ":" | sed -r "s|(.)$|\1\%|"> $tmp_dir/questions.list
            test -n "$category" && category_aux="$(echo "$category" | sed -r 's|([\.-])|\\\1|g;s|/$||')" && where="$where 1=~$faq_dir_tree/${category_aux}/.*"
            test -n "$tag" && tag_aux="$(echo "$tag" | sed -r 's|([\.-])|\\\1|g')" && where="$where 3=~(.+[[:blank:]])*${tag_aux}([[:blank:]].+)*"
            test -n "$where" && where="-w $where"

            query_file.sh -d "%" -r ";" \
                -s 1 2 3 4 \
                -f $tmp_dir/questions.list \
                $where \
                -o 1 4 asc \
                > $tmp_dir/results

            display_faq

        ;;

        "$proceed_view")

            query_file.sh -d "%" -r ";" \
                -s 1 2 3 4 \
                -f $tmp_dir/questions.list \
                -w "1=~$faq_dir_tree/$(echo "$category" | sed -r 's|([\.-])|\\\1|g;s|/$||')/" "2==$(echo "$question" | sed -r 's|([\.-])|\\\1|g')" \
                -o 1 4 asc \
                > $tmp_dir/results

            display_faq

        ;;

        "$proceed_new")

            test -f "$question_file" && question_filename="$(basename $question_file)" || end 1
            test -n "$tag" && valid "tag" "regex_faq_taglist" "<p><b<Erro. Lista de tags inválida: '$tag'</b></p>"

            valid "question_filename" "regex_faq_filename" "<p><b<Erro. Nome de arquivo inválido: '$question'</b></p>"
            valid "category" "regex_faq_category" "<p><b<Erro. Categoria inválida: '$category'</b></p>"

            query_file.sh -d "%" -r "" \
                -s 1 2 3 4 \
                -f $tmp_dir/questions.list \
                -w "1=~$faq_dir_tree/$(echo "$category" | sed -r 's|([\.-])|\\\1|g;s|/$||')/" "2==$(echo "$question" | sed -r 's|([\.-])|\\\1|g')" \
                -o 1 4 asc \
                > $tmp_dir/results

            if [ "$(cat $tmp_dir/results | wc -l)" -eq 0 ]; then

                question_txt="$(head -n 1 "$question_file")"
                question_dir="$(echo "$faq_dir_tree/$category" | sed -r "s|/+|/|g;s|/$||")"
                mkdir -p "$question_dir"
                cp "$question_file" "$question_dir/%$question_filename%$tag%"

                echo "<p><b>Tópico '$question_txt' adicionado com sucesso.</b></p>"

            else

                echo "<p><b>Há um tópico conflitante. Favor removê-lo antes de continuar:</b></p>"
                cat $tmp_dir/results | sed -r "s|^([^;]*);([^;]*);([^;]*);([^;]*);$|arquivo: \'\2\'; tópico: \'\4\'; categoria: \'\1\'; tags: \'\3\'|" | sed -r "s|(; categoria: \')$faq_dir_tree/|\1|"

            fi

        ;;

        "$proceed_remove")

            test -f "$question_file" || end 1

            question_txt="$(head -n 1 "$question_file")"
            question_dir="$(dirname "$question_file")"
            rm -f "$question_file"
            rmdir "$question_dir" &> /dev/null
            question_dir="$(dirname "$question_dir")"

            while [ "$question_dir" != "$faq_dir_tree" ]; do
                rmdir "$question_dir" &> /dev/null
                question_dir="$(dirname "$question_dir")"
            done

            echo "<p><b>Tópico '$question_txt' removido.</b></p>"

        ;;

        *) end 1 ;;

    esac

fi

end 0
