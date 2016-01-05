#!/bin/bash

function deploy_pkg () {

	# encontrar local de implantação da aplicação $app
	app_deployed="$($wildfly_cmd --command="deployment-info --server-group=*" | grep "$app.$ext")"
	app_srvgroup="$($wildfly_cmd --command="deployment-info --name=$app.$ext" | grep "enabled" | cut -f1 -d ' ')"

	if [ -n $app_deployed ]; then

		echo "$app_srvgroup" | while read group; do

			log "INFO" "Removendo a aplicação $app do server-group $group"

			# parar a respectiva instância do servidor de aplicação
			$wildfly_cmd --command="undeploy $app.$ext --server-groups=$group" || exit 1

			# efetuar deploy do pacote $pkg no diretório de destino, renomeando-o para $app.$ext
			# reiniciar instância do servidor de aplicação
			$wildfly_cmd --command="deploy $pkg --name=$app.$ext --server-groups=$group" || exit 1

			# registrar sucesso do deploy no log do agente e no histórico de deploy
			log "INFO" "Deploy do arquivo $pkg realizado com sucesso no server-group $group"
			write_history "Deploy da aplicação $app realizado com sucesso no server-group $group"

		done

	else

		log "ERRO" "Não foi encontrado deploy anterior da aplicação $app" && exit 1

	fi

	# remover pacote do diretório de origem
	rm -f $pkg

}

function copy_log () {

	# registrar o início do processo de cópia de logs no log do agente
	log "INFO" "Buscando logs da aplicação $app..."

	# localizar logs específicos da aplicação $app e/ou do servidor de aplicação
	app_deployed="$($wildfly_cmd --command="deployment-info --server-group=*" | cut -f1 -d ' ' | grep -Ex "$app\..+")"
	app_srvgroup="$($wildfly_cmd --command="deployment-info --name=$app_deployed" | grep "enabled" | cut -f1 -d ' ')"

	if [ -n $app_deployed ]; then

		echo "$app_srvgroup" | while read group; do

            hc=$(find $wildfly_dir/ -type d -maxdepth 1 -iname 'hc*' 2> /dev/null)
            
            echo "$hc" | while read hc_dir; do
                
                hc_name=$(basename $hc_dir)
                srvconf=$(cat $hc_dir/configuration/host-slave.xml | grep -E "group=(['\"])?$group(['\"])?" | sed -r "s|^.*name=['\"]?([^'\"]+)['\"]?.*$|\1|")
    			app_log_dir=$(find $hc_dir/ -type d -iwholename "$hc_dir/servers/$srvconf/log" 2> /dev/null)
    
				if [ -d  "$app_log_dir" ] && [ -f "$app_log_dir/server.log" ]; then

					# copiar arquivos para o diretório $shared_log_dir
					log "INFO" "Copiando logs da aplicação $app no diretório $app_log_dir"
					cd $app_log_dir; zip -rql1 ${shared_log_dir}/logs_${hc_name}_${srvconf}.zip *; cd - > /dev/null
					cp -f $app_log_dir/server.log $shared_log_dir/server_${hc_name}_${srvconf}.log

				else

					log "INFO" "Nenhum arquivo de log foi encontrado sob o diretório $app_log_dir"

				fi

			done

		done

	else

		log "ERRO" "Não foi encontrado deploy anterior da aplicação $app" && exit 1

	fi
}

# Validar variáveis específicas
test -f $wildfly_dir/bin/jboss-cli.sh || exit 1
test -n $controller_hostname || exit 1
test -n $controller_port || exit 1
test -n $user || exit 1
test -n $password || exit 1

# testar conexão
wildfly_cmd="$wildfly_dir/bin/jboss-cli.sh --connect --controller=$controller_hostname:$controller_port --user=$user --password=$password"
$wildfly_cmd --command="deployment-info --server-group=*" > /dev/null || exit 1

# executar função de deploy ou cópia de logs
case $1 in
	log) copy_log;;
	deploy) deploy_pkg;;
	*) log "ERRO" "O script somente admite os parâmetros 'deploy' ou 'log'.";;
esac