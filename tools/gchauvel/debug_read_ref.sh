#! /bin/bash

ps fauxw | grep GerritCodeReview | awk '{ print $2 }' | xargs kill

BASEDIR="/home/gchauvel"
declare -A gerrit_ko=(["port"]=29418 ["http"]=8080 ["name"]="gerrit-3.1.2" ["file"]="${BASEDIR}/Downloads/gerrit-3.1.2.war" ["gitremote"]="remoteko")
declare -A gerrit_ok=(["port"]=29419 ["http"]=8081 ["name"]="gerrit-patch" ["file"]="${BASEDIR}/gerrit.git/bazel-bin/gerrit.war" ["gitremote"]="remoteok")
#declare -a dict=("gerrit_ko" "gerrit_ok")
declare -a dict=("gerrit_ok")
#declare -A repoval=( ["A"]=1 ["B"]=2)
declare -A repoval=( ["A"]=1 )

BASETESTDIR="${BASEDIR}/debug_perm"

for REPOID in "${!repoval[@]}"; do
    USERNUM=${repoval[$REPOID]}
    REPO="repo${REPOID}"
    export GIT_WORK_TREE="${BASETESTDIR}/${REPO}"
    export GIT_DIR="${GIT_WORK_TREE}/.git"
    rm -rf ${GIT_WORK_TREE}
    mkdir -p ${GIT_DIR}
    git init
    git config --local --add user.name "User ${USERNUM}"
    git config --local --add user.email "user${USERNUM}@testgerrit.com"
    touch ${GIT_WORK_TREE}/README.txt
    git add README.txt
    git commit -m "1st commit"
done
unset GIT_DIR
unset GIT_WORK_TREE

for member in "${dict[@]}"; do
    declare -n p="$member"
    PORT=${p["port"]}
    HTTPD=${p["http"]}
    GITREMOTE=${p["gitremote"]}
    USERNUM=${p["usernum"]}
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p ${PORT}"
    USERHOST="admin@localhost"
    SSH="${GIT_SSH_COMMAND} ${USERHOST}"

    GERRITWAR="${p['file']}"
    TESTDIR="${BASETESTDIR}/${p['name']}"

    echo "STOP GERRIT"
    ${TESTDIR}/gerrit/bin/gerrit.sh stop
    sleep 1
    
    rm -rf ${TESTDIR}/gerrit

    echo "INIT GERRIT"
    java -jar ${GERRITWAR} init --batch --dev --no-auto-start -d ${TESTDIR}/gerrit
    if [ ! -f ${BASETESTDIR}/gerrit.config ] ; then
        cp ${TESTDIR}/gerrit/etc/gerrit.config ${BASETESTDIR}/gerrit.config
    else
        cp ${BASETESTDIR}/gerrit.config ${TESTDIR}/gerrit/etc/gerrit.config
        git config --file ${TESTDIR}/gerrit/etc/gerrit.config --replace-all sshd.listenAddress *:${PORT}
        git config --file ${TESTDIR}/gerrit/etc/gerrit.config --replace-all httpd.listenUrl http://*:${HTTPD}/
    fi

    ${TESTDIR}/gerrit/bin/gerrit.sh start
    if [ $? -ne 0 ] ; then
		echo "Cannot start gerrit, exiting"
		exit 1
	fi
    sleep 1
    
	${SSH} gerrit version
	if [ $? -ne 0 ] ; then
		echo "Something is wrong with ssh, Cannot get gerrit version"
		exit 1
	fi
	
    ${SSH} gerrit create-account user1 --full-name "User\ 1" --email "user1@testgerrit.com" --http-password "user1"
    ${SSH} gerrit create-account user2 --full-name "User\ 2" --email "user2@testgerrit.com" --http-password "user2"
    ${SSH} gerrit create-group devel --member user1 --member user2 --description "devel\ Group"

    echo "CREATE REPO1"
    ${SSH} gerrit create-project repo1
    sleep 1

    echo "CLONE ALL PROJ"
    rm -rf ${TESTDIR}/All-Projects
    git clone ${USERHOST}:All-Projects ${TESTDIR}/All-Projects
    cd ${TESTDIR}/All-Projects
    git config --local --replace-all remote.origin.fetch +refs/*:refs/remotes/origin/*
    git fetch
    git checkout -b meta/config origin/meta/config
    git config --file project.config --unset access.refs/*.read "group Anonymous Users"
    git config --file project.config --add access.refs/*.read "deny group Anonymous Users"
    git config --local --add user.name Admin
    git config --local --add user.email "admin@example.com"
    git add --all
    git commit -m "new conf"
    git push origin meta/config:refs/meta/config
    sleep 1

    echo "CLONE REPO1"
    rm -rf ${TESTDIR}/repo1admin
    git clone ${USERHOST}:repo1 ${TESTDIR}/repo1admin
    cd ${TESTDIR}/repo1admin
    git config --local --replace-all remote.origin.fetch +refs/*:refs/remotes/origin/*
    git fetch
    git checkout -b meta/config origin/meta/config
    ${SSH} gerrit ls-groups -v | grep devel | awk '{ print $2,"\t",$1 }' > groups

    REGEXP_ON=1
    if [ ${REGEXP_ON} -eq 1 ] ; then
		#git config --file project.config --add 'access.^refs/heads/.+.read' "group devel"
        git config --file project.config --add 'access.^refs/heads/users/${username}/(public|private)/.+.read' "group devel"
        #git config --file project.config --add 'access.^refs/heads/users/${username}/(public|private)/.+.create' 'group devel'
        #git config --file project.config --add 'access.^refs/heads/users/${username}/(public|private)/.+.push' '+force group devel'
        #git config --file project.config --add 'access.^refs/heads/users/${username}/(public|private)/.+.delete' 'group devel'
        #git config --file project.config --add 'access.^refs/heads/users/.+/public/.+.read' 'group devel'
    else
        git config --file project.config --add 'access.refs/heads/users/${username}/public/*.read' "group devel"
        git config --file project.config --add 'access.refs/heads/users/${username}/public/*.create' 'group devel'
        git config --file project.config --add 'access.refs/heads/users/${username}/public/*.push' 'group devel'
    fi
    #git config --file project.config --add 'access.refs/heads/tata.read' 'group devel'
    git config --local --add user.name Admin
    git config --local --add user.email "admin@example.com"
    git add --all
    git commit -m "new conf"
    git push origin meta/config:refs/meta/config
    
    ${TESTDIR}/gerrit/bin/gerrit.sh stop
    rm -f ${TESTDIR}/gerrit/logs/*
    ${TESTDIR}/gerrit/bin/gerrit.sh start
done

#for REPOID in "A" "B" ; do
for REPONUM in "A" ; do
    for member in "${dict[@]}"; do
        declare -n p="$member"
        HTTPD=${p["http"]}
        GITREMOTE=${p["gitremote"]}
        USERNUM=${p["usernum"]}

        #for USERNUM in 1 2 ; do
        for USERNUM in 1 ; do
            export GIT_WORK_TREE="${BASETESTDIR}/repo${REPOID}"
            export GIT_DIR="${GIT_WORK_TREE}/.git"
            git remote add ${GITREMOTE}_user${USERNUM} http://user${USERNUM}:user${USERNUM}@localhost:${HTTPD}/a/repo1
        done
    done
done

echo "
=== TEST PUSH ==="
#for REPOID in "A" "B" ; do
for REPOID in ; do
    export GIT_WORK_TREE="${BASETESTDIR}/repo${REPOID}"
    export GIT_DIR="${GIT_WORK_TREE}/.git"
    REPONUM=${repoval[$REPOID]}

    for member in "${dict[@]}"; do
        declare -n p="$member"
        HTTPD=${p["http"]}
        GITREMOTE=${p["gitremote"]}

        for USERNUM in 1 ; do
			
			if [ ${REPONUM} -eq ${USERNUM} ] ; then
				git push -f ${GITREMOTE}_user${USERNUM} HEAD:refs/heads/users/user${USERNUM}/public/a >/dev/null 2>&1
				if [ $? -ne 0 ] ; then
					echo "in repo${REPOID} push to ${GITREMOTE}_user${USERNUM} HEAD:refs/heads/users/user${USERNUM}/public/a FAILED!"
				else
					echo "in repo${REPOID} push to ${GITREMOTE}_user${USERNUM} HEAD:refs/heads/users/user${USERNUM}/public/a OK"
				fi
				#git push -f ${GITREMOTE}_user${USERNUM} HEAD:refs/heads/users/user${USERNUM}/private/a >/dev/null 2>&1
				#if [ $? -ne 0 ] ; then
				#	echo "in repo${REPOID} push to ${GITREMOTE}_user${USERNUM} HEAD:refs/heads/users/user${USERNUM}/private/a FAILED!"
				#else
				#	echo "in repo${REPOID} push to ${GITREMOTE}_user${USERNUM} HEAD:refs/heads/users/user${USERNUM}/private/a OK"
				#fi
            fi
        done
    done
done

echo "=== TEST FETCH ==="
#for REPOID in "A" "B" ; do
for REPOID in "A"; do
    export GIT_WORK_TREE="${BASETESTDIR}/repo${REPOID}"
    export GIT_DIR="${GIT_WORK_TREE}/.git"
    REPONUM=${repoval[$REPOID]}

    for member in "${dict[@]}"; do
        declare -n p="$member"
        HTTPD=${p["http"]}
        GITREMOTE=${p["gitremote"]}
        
        for USERNUM in 1 ; do
			if [ ${REPONUM} -eq ${USERNUM} ] ; then
				echo "fetch ${GITREMOTE}_user${USERNUM}"
				git fetch ${GITREMOTE}_user${USERNUM}
			fi
		done
	done
done
