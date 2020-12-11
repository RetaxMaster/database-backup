#!/bin/bash
# Shell script para obtener una copia desde mysql
# Desarrollado por RetaxMaster

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

set -e

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

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

function update_files(){
	local NUMBER_OF_BACKUPS="$(ls $HOME/mysql | wc -l)"

	echo "Encontrados ${NUMBER_OF_BACKUPS} archivos"

	if [[ $NUMBER_OF_BACKUPS -gt 7 ]]; then
		# Lista los archivos dentro de la carpeta $HOME/mysql, los ordena de menor a mayor y solo toma el primero
		local OLDER_FILE="$(ls $HOME/mysql | sort | head -n 1)"
		echo "Older file: ${OLDER_FILE}"
		rm $HOME/mysql/$OLDER_FILE
		echo "Eliminado ${OLDER_FILE}"
		# Recursividad para eliminar todos hasta que solo queden 7
		update_files
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
	local BUCKET=$DB_BCKP_BUCKET

	[ ! -d "$BAK" ] && mkdir -p "$BAK"

	FILE=$BAK/$DATABASE.$NOW-$(date +"%T").gz

	local SECONDS=0

	$MYSQLDUMP -u $USER -h $HOST -p$PASS $DATABASE | $GZIP -9 > $FILE

	duration=$SECONDS
	echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
	update_files
	aws s3 cp $BAK "s3://$BUCKET" --recursive
}

run
make_backup
