#!/bin/sh

FULL_PATH="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
if [[ ! -f $FULL_PATH"/giploy.conf" ]]; then
	cat <<EOT
Program did not find giploy.conf file
EOT
	exit 1
fi

. giploy.conf

if [[ $LOG_FILENAME -eq "" ]]; then
	LOG_FILENAME=$FULL_PATH"/giploy-`date '+%Y-%m-%d_%H-%k'`.log"
fi

if [[ ! -d $REPOSITORY ]]; then
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
if [[ $OUT -ne 0 ]]; then
	cat <<EOT
Your folder appears to be not a git repository
EOT
	exit 1
fi

log() {
	echo "["`date`"] "$*
}

if [[ -f "README" ]]; then
	VERSION=`cat README | awk -F " " '/v/{print $2}' | awk -F "v" '{print $2}'`
	if [[ $VERSION =~ ^[0-9]\.[0-9]+\.?[0-9]?$ ]]; then
		IFS='.' read -r -a versions <<< "$VERSION"
		MAJOR=${versions[0]}
		MINOR=${versions[1]}
		CURRENT_VERSION=$MAJOR"."$MINOR
		NEXT_VERSION=$MAJOR"."$((MINOR+1))
	else
		cat <<EOT
README isn't correctly formated
ex: My Project v1.0.2
EOT
		exit 1
	fi
else
	cat <<EOT
You don't have a README file in your repository with the version
ex: My Project v1.0.2
EOT
	exit 1
fi

usage() {
        cat <<EOT
usage: $0 [opts] [remote name]
options : 
	--no-bump	disable update of your README file
	--no-tag	disable tag creation of your release
	--dry-run	run but don't push to remote, helpful to test the process
	-v 		Display current version
EOT
        exit 1
}

create_release_branch() {
	git fetch > $LOG_FILE 2>&1 >> /dev/null
	git checkout develop >> $LOG_FILE 2>&1 >> /dev/null
	git reset --hard HEAD >> $LOG_FILE 2>&1 >> /dev/null
	git clean -f -d >> $LOG_FILE 2>&1 >> /dev/null
	git checkout develop >> $LOG_FILE 2>&1 >> /dev/null
	git pull origin develop >> $LOG_FILE 2>&1 >> /dev/null
	$(git checkout -b release/v$NEXT_VERSION >> $LOG_FILE 2>&1 >> /dev/null) 
	OUT=$? 
	return "$OUT"
}

bump_version() {
	cat README | sed -i.bak "s/v$CURRENT_VERSION/v$NEXT_VERSION/g" README
	cat constants.php | sed -i.bak "s/define('ENVIRONMENT', 'development');/define('ENVIRONMENT', 'production');/g" constants.php
	git commit -a -m "Release v$NEXT_VERSION" >> $LOG_FILE 2>&1 >> /dev/null
	OUT=$? 
	return "$OUT"
}

merge_release_branch() {
	git checkout master >> $LOG_FILE 2>&1 >> /dev/null
	$(git merge release/v$NEXT_VERSION >> $LOG_FILE 2>&1 >> /dev/null)
	OUT=$? 
	return "$OUT"
}

tag_release() {
	$(git tag -a -m "Release/v$NEXT_VERSION" release/$NEXT_VERSION >> $LOG_FILE 2>&1 >> /dev/null)
	OUT=$? 
	return "$OUT"
}

push_to_origin() {
	git push --tags -f origin master >> $LOG_FILE 2>&1 >> /dev/null
	OUT=$? 
	if [ $OUT -eq 0 ]; then
		log "merge des modifs sur develop"
		git checkout develop >> $LOG_FILE 2>&1 >> /dev/null
		$(git merge release/v$NEXT_VERSION >> $LOG_FILE 2>&1 >> /dev/null)
		git push origin develop >> $LOG_FILE 2>&1 >> /dev/null
	fi
	$(git branch -d release/v$NEXT_VERSION >> $LOG_FILE 2>&1 >> /dev/null)
	OUT=$? 
	return "$OUT"
}

push_to_remote() {
	checkout=true
	for s in $as
	do
		$(git push $s master >> $LOG_FILE 2>&1 >> /dev/null)
		local OUT=$? 
		if [ $OUT -eq 0 ]; then
			log "Push on $s : DONE"
		else
			log "Failed to push on $s"
			log $OUT
			checkout=false
		fi
	done

	if [ $checkout ]; then
		git checkout develop >> $LOG_FILE 2>&1 >> /dev/null
	fi
}

dry_run=false
bump=true
tag=true

if [ $# -gt 0 ]; then
	for arg in "$@"; do
		shift
		case "$arg" in
			"--dry-run") set -- "$@" "-d" ;;
			"--no-bump") set -- "$@" "-b" ;;
			"--no-tag")   set -- "$@" "-t" ;;
			"--help")   set -- "$@" "-h" ;;
			*)        set -- "$@" "$arg"
		esac
	done

	while getopts "hbdtv" option
	do
		case $option in
			b)
				bump=false
				;;
			d)
				dry_run=true
				;;
			t)
				tag=false
				;;
			h)
				usage
				;;
			v)
				log "Current Release : "$CURRENT_VERSION
				log "Next Release : "$NEXT_VERSION
				exit 1
				;;
			\?)
				exit 1
				;;
		esac
	done

    shift $((OPTIND-1))
	SERVER=$1
	SERVER="$(echo "${SERVER}" | tr -d '[[:space:]]')"

	if [[ -ne $SERVER ]]; then
		IFS="," read -r -a as <<< $REMOTES
		if [[ " ${as[@]} " =~ " $SERVER " ]]; then
			as=$1
			log "push only on remote : "$as
		else
			log "Server not found"
			usage
		fi
	else
		log "no remote provided"
	fi
else
	IFS="," read -r -a as <<< $REMOTES
fi

log "Release v"$NEXT_VERSION" started"
create_release_branch
ret=$?
if [[ $ret -eq 0 ]]; then
	log "Release branch creation" 
else
	cat <<EOT
An error occurred during branch creation.
Check log file ($LOG_FILE)
EOT
	exit 1
fi

if $bump; then
	bump_version
	ret=$?
	if [[ $ret -eq 0 ]]; then
		log "Bump ok"
	else
		cat <<EOT
An error occurred during bump processing.
Check log file ($LOG_FILE)
EOT
		exit 1
	fi
fi

merge_release_branch
ret=$?
if [[ $ret -eq 0 ]]; then
	log "Release branch merging"
else
	cat <<EOT
An error occurred during merging.
Please fix conflicts and commit your changes
EOT
	exit 1
fi

if $tag; then
	tag_release
	ret=$?
	if [[ $ret -eq 0 ]]; then
		log "Release Tag"
	else
		cat <<EOT
An error occurred during tag creation.
Check log file ($LOG_FILE)
EOT
		exit 1
	fi
fi

if $dry_run; then
	log "Everything run fine, Release v"$NEXT_VERSION" ready to production !"
else
	push_to_origin
	ret=$?
	if [[ $ret -eq 0 ]]; then
		log "Push to origin server"
	else
		cat <<EOT
An error occurred during push to origin.
Check log file ($LOG_FILE)
EOT
		exit 1
	fi

	log "Push to remote servers"
	push_to_remote
	ret=$?
	if [[ ! $ret -eq 0 ]]; then
		cat <<EOT
An error occurred during push to remote servers.
Please, read your log file ($LOG_FILE)
EOT
		exit 1
	fi
	log "Everything run fine, Release v"$NEXT_VERSION" in production !"
fi

exit 0
