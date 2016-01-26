#!/usr/bin/env bash

#set -e
#set -u

FULL_PATH="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
if [ ! -f $FULL_PATH"/giploy.conf" ]; then
	cat <<EOT
Program did not find giploy.conf file
EOT
	exit 1
fi

. $FULL_PATH/giploy.conf

if [ -z $LOG_FILENAME ]; then
	LOG_FILENAME=$FULL_PATH"/giploy-init-`date '+%Y-%m-%d_%H-%M'`.log"
fi

if [ ! -d $REPOSITORY ]; then
	cat <<EOT
Be sure to specify a correct path to your repository
EOT
	exit 1
fi

LOG_FILE=$LOG_FILENAME

cd $REPOSITORY;

if ! type "git" > /dev/null; then
	cat <<EOT
Git is not installed on your system
EOT
	exit 1
fi

git status > /dev/null 2>&1
OUT=$? 
if [ $OUT -ne 0 ]; then
	cat <<EOT
Your folder appears to be not a git repository
EOT
	exit 1
fi

log() {
	echo "["`date`"] "$*
}

usage() {
	cat <<EOT
usage: $0 -u vagrant -H 127.0.0.1 -p 2222 -r /var/www/website <remote_name>
options : 
	-u 	User to connect to your remote server
	-H 	Hostname
	-p 	Post number
	-r 	Remote root directory
EOT
	exit 1
}

while getopts "p:u:H:r:h" option
do
	case $option in
		p)
			REMOTE_PORT=$OPTARG
			;;
		u)
			REMOTE_USER=$OPTARG
			;;
		H)
			REMOTE_HOSTNAME=$OPTARG
			;;
		r)
			ROOT_DIRECTORY=$OPTARG
			;;
		h)
			usage
			;;
		:)
			usage
			exit 1
			;;
		\?)
			exit 1
			;;
	esac
done

shift $((OPTIND-1))
REMOTE_NAME=$1
REMOTE_NAME="$(echo "${REMOTE_NAME}" | tr -d '[[:space:]]')"

if [ -z $REMOTE_NAME ]; then
	usage
fi

if [ $OPTIND -ne 9 ]; then
	cat <<EOT
please provide every arguments
EOT
	usage
fi

log "init directory on remote server"
ssh -p $REMOTE_PORT $REMOTE_USER"@"$REMOTE_HOSTNAME "mkdir -p /home/"$REMOTE_USER"/website.git && cd /home/"$REMOTE_USER"/website.git && git init --bare && cat > hooks/post-receive <<EOT 
#!/bin/sh
GIT_WORK_TREE="$ROOT_DIRECTORY" git checkout -f
EOT
chmod +x hooks/post-receive && mkdir -p "$ROOT_DIRECTORY"
" >> $LOG_FILE 2>&1 >> /dev/null

OUT=$? 
if [ $OUT -ne 0 ]; then
	cat <<EOT
Remote connection failed
$OUT
EOT
	exit 1
fi
cd $REPOSITORY;
log "add remote server to your git project"
git remote add $REMOTE_NAME "ssh://"$REMOTE_USER"@"$REMOTE_HOSTNAME":"$REMOTE_PORT"/home/"$REMOTE_USER"/website.git" >> $LOG_FILE 2>&1 >> /dev/null
log "push master branch to init remote server"
git push $REMOTE_NAME +master:refs/heads/master >> $LOG_FILE 2>&1 >> /dev/null

cd $FULL_PATH;
log "add remote server to your giploy.conf"
cat giploy.conf | sed -i.bak "s/REMOTES=\(\"*\)\([^\"]*\)\(\"*\)/REMOTES\=\"\2,$REMOTE_NAME\"/g" giploy.conf

log "Remote server : "$REMOTE_NAME" was correctly installed"

exit 0
