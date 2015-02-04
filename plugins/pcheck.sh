#!/bin/bash

# Trigger the given plugin precheck against the given stable brancg

function print_usage {
cat << EOF

Usage:
    $ pcheck.sh <zipfile> <moodlebranch> <pluginversionid> [<component>]

Example:
    $ pcheck.sh ~/tmp/moodle-mod_foobar_moodle27_2014051200.zip 27 12345

EOF
}

#
# Your environment configuration
#
GITSNAPSHOTS=/home/mudrd8mz/git/moodle-plugins-snapshots
UTILPATH=/home/mudrd8mz/www/mdk/m29/moodle/admin/tool/installaddon/cli/util.php
UTIL="/usr/bin/php ${UTILPATH}"

set -e

EX_USAGE=64
EX_ENV=63
EX_ABORTED=62

if [[ $# < 3 || $1 == '--help' || $1 == '-h' ]]; then
    print_usage
    exit ${EX_USAGE}
fi

ZIPPATH=$(readlink -f $1)
ZIP=$(basename ${ZIPPATH})
MOODLEVER=$2
PLUGINVERID=$3

if [[ ! -f ${ZIPPATH} ]]; then
    echo "plugin zip file not found: ${ZIPPATH}"
    exit ${EX_USAGE}
fi

if [[ ! -e ${GITSNAPSHOTS} ]]; then
    echo "plugins snapshots repository not found: ${GITSNAPSHOTS}"
    exit ${EX_ENV}
fi

if [[ ! -f ${UTILPATH} ]]; then
    echo "The helper utility ${UTILPATH} not found"
    exit ${EX_ENV}
fi

echo
echo "== Analysing the zip contents =="
echo

if [[ -z $4 ]]; then
    COMPONENT=$(${UTIL} --component ${ZIPPATH})
else
    COMPONENT="$4"
fi
echo "component:    ${COMPONENT}"

DIRNAME=$(${UTIL} --dirname ${ZIPPATH})
echo "dirname:      ${DIRNAME}"

NORMALIZE=$(${UTIL} --normalize ${COMPONENT})

TYPE=$(echo -n "${NORMALIZE}" | cut -f1)
echo "type:         ${TYPE}"

NAME=$(echo -n "${NORMALIZE}" | cut -f2)
echo "name:         ${NAME}"

TYPEROOT=$(${UTIL} --typeroot ${TYPE})
echo "typeroot:     ${TYPEROOT}"

BRANCH="${PLUGINVERID}-${MOODLEVER}-${COMPONENT}"
echo "branch:       ${BRANCH}"

if [[ ${DIRNAME} != ${NAME} ]]; then
    DORENAME="--rename=${NAME}"
else
    DORENAME=""
fi

echo
echo == Plugin validation results ==
echo
${UTIL} --validate --type=${TYPE} ${DORENAME} --version=9999999999 ${ZIPPATH}

echo
read -p "continue [y/n]" -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit ${EX_ABORTED}
fi

pushd ${GITSNAPSHOTS}
git fetch moodle

if git show-ref --verify --quiet refs/heads/${BRANCH}; then
    git checkout ${BRANCH}
    git reset --hard moodle/MOODLE_${MOODLEVER}_STABLE
else
    git checkout --no-track -b ${BRANCH} moodle/MOODLE_${MOODLEVER}_STABLE
fi

git clean -df

if [[ ! -f version.php ]] || [[ ! -f config-dist.php ]] || [[ ! -f lib/moodlelib.php ]]; then
    echo "${PWD} does not look like the dirroot of a Moodle instance"
    exit ${EX_ENV}
fi

TARGET=${PWD}/${TYPEROOT}

if [[ ! -w ${TARGET} ]]; then
    echo
    echo "target directory not writable: ${TARGET}"
    exit ${EX_ENV}
fi

if [[ -e ${TARGET}/${ZIP} || -e ${TARGET}/${DIRNAME} || -e ${TARGET}/${NAME} ]]; then
    echo
    echo "sorry, unpacking the zip would overwrite some existing contents in ${TARGET}"
    exit ${EX_ENV}
fi

cp --verbose --no-clobber ${ZIPPATH} ${TARGET}
pushd ${TARGET}
unzip ${ZIP}

if [[ ${DIRNAME} != ${NAME} ]]; then
    mv ${DIRNAME} ${NAME}
fi

rm ${TARGET}/${ZIP}

popd

echo
echo == git status ==
echo
git status

echo
read -p "commit the snapshot [y/n]" -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit ${EX_ABORTED}
fi

git add ${TARGET}/${NAME}
git commit --author="Plugins bot <plugins@moodle.org>" -m "PLUGIN-${PLUGINVERID} ${COMPONENT}: cibot precheck request"

echo
read -p "push to the public repo [y/n]" -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit ${EX_ABORTED}
fi

git push -f origin

CIREMOTE="https://git.in.moodle.com/mudrd8mz/moodle-plugins-snapshots.git"
CIBRANCH="${BRANCH}"
CIINTEGRATETO="MOODLE_${MOODLEVER}_STABLE"
CIISSUE="PLUGIN-${PLUGINVERID}"

# Ask for the confirmation.
echo
echo "Repository:   $CIREMOTE"
echo "Branch:       $CIBRANCH"
echo "Integrate to: $CIINTEGRATETO"
echo "Issue:        $CIISSUE"
echo

read -p "Perform the CI precheck with these parameters? [y/n]" -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit
fi

# CI server performing the precheck.
CIHOST="http://integration.moodle.org"
#CIHOST="http://ci.stronk7.com"
CIJOB="Precheck%20remote%20branch"
CITOKEN="we01allow02tobuild04this05from06remote07scripts08didnt09you10know"

# Ask Jenkins to schedule a new job build.
echo -n "Scheduling a new job build ... "
curlresult=$(curl --silent --request POST --dump-header - --data-urlencode token=${CITOKEN} --data-urlencode remote=${CIREMOTE} --data-urlencode branch=${CIBRANCH} --data-urlencode integrateto=${CIINTEGRATETO} --data-urlencode issue=${CIISSUE} --data-urlencode rebasewarn=999 --data-urlencode rebaseerror=999 --data-urlencode filter=true ${CIHOST}/job/${CIJOB}/buildWithParameters)

# The successful queueing will result in 201 status code
# with Location HTTP header pointing the URL of the item in the queue.
if [[ $(echo "$curlresult" | head -n 1 | tr -d '\n\r') != "HTTP/1.1 201 Created" ]]; then
    echo "Unexpected cURL result:"
    echo "-----------------------"
    echo "$curlresult"
    echo "-----------------------"
    exit 1;
fi

# Get the URL of the queue item.
location=$(echo "$curlresult" | grep '^Location: ' | cut -c 11- | tr -d '\n\r')
echo "OK [${location}api/xml]"

# Poll the queue item to track the status of the queued task.
echo -n "Waiting for the build start "
while true; do
    echo -n .
    sleep 5
    curlresult=$(curl --silent --include --data-urlencode xpath='/leftItem/executable[last()]/url' ${location}api/xml)
    if [[ $(echo "$curlresult" | head -n 1 | tr -d '\n\r') == "HTTP/1.1 200 OK" ]]; then
        break
    fi
done

buildurl=$(echo "$curlresult" | grep '^<url>' | tr -d '\n\r' | cut -c 6- | rev | cut -c 7- | rev)
echo "OK [${buildurl}]"
echo "-----------------------"

# Bytes offset of the raw log file
textsize=0

while true; do
    headers=$(curl --dump-header /dev/stderr --data start=${textsize} {$buildurl}logText/progressiveText 2>&1 >/dev/tty)
    textsize=$(echo "${headers}" | grep 'X-Text-Size: ' | tr -d '\n\r')
    textsize=${textsize##X-Text-Size: }
    moredata=$(echo "${headers}" | grep 'X-More-Data: true' | tr -d '\n\r')

    if [ -z "$moredata" ]; then
        break
    fi

    sleep 5
done
echo "-----------------------"
echo
echo "Status:           ${buildurl}"
echo "Console Output:   ${buildurl}console"
echo "Parameters:       ${buildurl}parameters"
echo "Build Artifacts:  ${buildurl}artifact/work/"
echo "smurf.html:       ${buildurl}artifact/work/smurf.html"
