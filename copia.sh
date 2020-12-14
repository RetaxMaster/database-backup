#!/bin/bash
# Shell script para obtener una copia desde mysql
# Desarrollado por RetaxMaster

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

set -e

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
DATABASE=$DB_BCKP_DATABASE
BUCKET=$DB_BCKP_BUCKET/$DATABASE

function assert_is_installed() {
	local readonly name="$1"

	if [[ ! $(command -v ${name}) ]]; then
		log_error "El binario '$name' se requiere pero no esta en nuestro sistema"
		exit 1
	fi
}

function log_error() {
	local readonly message "$1"
	log "ERROR" "$message"
}

function log() {
	local readonly level="$1"
	local readonly message="$2"
	local readonly timestamp=$(date +"%Y-%m-$d %H:%M:%S") >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function run() {
	assert_is_installed "mysql"
        assert_is_installed "mysqldump"
        assert_is_installed "gzip"
        assert_is_installed "aws"
}

function check_files(){
	# Listo todo los archivos que hay en el bucket, al resultado le hago un split de espacios en blanco y obtengo la posicion 4 (El nombre del archivo), a este resultado le hago otro split a traves del caracter "/" para obtener unicamente el nombre
	local ALL_AMAZON_BACKUPS="$(aws s3 ls s3://$BUCKET --recursive | awk '{print $4}' | awk -F/ '{print $NF}')"
	local NUMBER_OF_BACKUPS="$(echo "$ALL_AMAZON_BACKUPS" | wc -l)"
	local OLDER_FILE="$(echo "$ALL_AMAZON_BACKUPS" | sort | head -n 1)"

	echo "Encontrados ${NUMBER_OF_BACKUPS} archivos almacenados en S3"

	# Si ya hay mas de 6 archivos, empezamos a eliminar los archivos viejos, 6 porque al escribir el nuevo archivo será el archiv numero 7
	if [[ $NUMBER_OF_BACKUPS -gt 6 ]]; then

		local OLDER_FILE="$(echo "$ALL_AMAZON_BACKUPS" | sort | head -n 1)"
		echo "Archivo mas viejo $OLDER_FILE"
		aws s3 rm "s3://$BUCKET/$OLDER_FILE"
		echo "Eliminado de S3: $OLDER_FILE"

        fi

}

function make_backup() {
	local BAK="$(echo $HOME/mysql)"
        local MYSQL="$(which mysql)"
        local MYSQLDUMP="$(which mysqldump)"
        local GZIP="$(which gzip)"
	local NOW="$(date +"%d-%m-%Y")"

	local USER=$DB_BCKP_USER
	local PASS=$DB_BCKP_PASS
	local HOST=$DB_BCKP_HOST
	local DATABASE=$DB_BCKP_DATABASE

	[ ! -d "$BAK" ] && mkdir -p "$BAK"

	FILENAME="$DATABASE-$NOW-$(date +"%H_%M_%S").gz"
	FILE=$BAK/$FILENAME

	local SECONDS=0

	$MYSQLDUMP -u $USER -h $HOST -p$PASS $DATABASE | $GZIP -9 > $FILE

	duration=$SECONDS
	echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."

	# Checamos los archivos para ver si hay mas de 7 y se elimina el mas viejo
	check_files

	# Subimos el nuevo backup que acabamos de crear
	echo "Empezando la subida a S3"
	aws s3 cp $BAK/$FILENAME s3://$BUCKET/$FILENAME

	#Eliminamos el archivo de este servidor
	echo "Eliminando el archivo de este servidor"
	rm $FILE

}
run
make_backup
