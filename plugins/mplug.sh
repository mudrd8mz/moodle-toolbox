#!/bin/bash -e

function print_usage {
cat << EOF
Installs the given Moodle plugin into this instance

Usage:
    $ mplug.sh <zipfile>

EOF
}

#
# Your environment configuration
#
UTILPATH=/home/mudrd8mz/www/mdk/m29/moodle/admin/tool/installaddon/cli/util.php
UTIL="/usr/bin/php ${UTILPATH}"
UPGRADE="/usr/bin/php admin/cli/upgrade.php"

#
# Exit statuses
#
EX_USAGE=64
EX_ENV=63

if [[ ! -f ${UTILPATH} ]]; then
    echo "The helper utility ${UTILPATH} not found"
    exit 1
fi

if [[ ! -f version.php ]] || [[ ! -f config.php ]] || [[ ! -f lib/moodlelib.php ]]; then
    echo "${PWD} does not look like the dirroot of a Moodle instance"
    exit 1
fi

if [[ $# < 1 || $# > 1 || $1 == '--help' || $1 == '-h' ]]; then
    print_usage
    exit ${EX_USAGE}
fi

ZIPPATH=$1
ZIP=$(basename ${ZIPPATH})

if [[ ! -f ${ZIPPATH} ]]; then
    echo "plugin zip file not found: ${ZIPPATH}"
    exit ${EX_USAGE}
fi

echo
echo "== Analysing the zip contents =="
echo

COMPONENT=$(${UTIL} --component ${ZIPPATH})
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

echo
echo "== Executing the plugin validation =="
echo

if [[ ${DIRNAME} != ${NAME} ]]; then
    DORENAME="--rename=${NAME}"
else
    DORENAME=""
fi

${UTIL} --validate --type=${TYPE} ${DORENAME} --version=9999999999 ${ZIPPATH}

echo
read -p "do you want to unpack the zip into ${TARGET} [y/n]" -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit
fi

echo -n "copying "
cp --verbose --no-clobber ${ZIPPATH} ${TARGET}

echo -n "changing working directory "
pushd ${TARGET}
unzip ${ZIP}

if [[ ${DIRNAME} != ${NAME} ]]; then
    mv ${DIRNAME} ${NAME}
fi

rm ${TARGET}/${ZIP}

echo -n "changing working directory back to "
popd

echo
echo "== the plugin has been successfully deployed =="
echo

${UPGRADE}
