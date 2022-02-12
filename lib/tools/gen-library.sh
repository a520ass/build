#!/usr/bin/env bash
set -e

SRC="$(
	cd "$(dirname "$0")/../.."
	pwd -P
)"
echo "SRC: ${SRC}"

TARGET_SH="${SRC}/lib/library-functions.sh"

echo "Writing ${TARGET_SH}"

cat <<- AUTOGEN_INCLUDES_HEADER > "${TARGET_SH}"
	#!/usr/bin/env bash
	# This file is/was autogenerated by ${0}; don't modify manually

AUTOGEN_INCLUDES_HEADER

find lib/functions -type f -name \*.sh | sort -h | while read -r path; do
	ref="$(echo -n "${path}")"
	cat <<- AUTOGEN_INCLUDES_EACH >> "${TARGET_SH}"
		# no errors tolerated. invoked before each sourced file to make sure.
		#set -o pipefail  # trace ERR through pipes - will be enabled "soon"
		#set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable - one day will be enabled
		set -o errtrace # trace ERR through - enabled
		set -o errexit  ## set -e : exit the script if any statement returns a non-true return value - enabled
		### ${path}
		# shellcheck source=${ref}
		source "\${SRC}"/${path}

	AUTOGEN_INCLUDES_EACH
done

cat <<- AUTOGEN_INCLUDES_FOOTER >> "${TARGET_SH}"

	# no errors tolerated. one last time for the win!
	#set -o pipefail  # trace ERR through pipes - will be enabled "soon"
	#set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable - one day will be enabled
	set -o errtrace # trace ERR through - enabled
	set -o errexit  ## set -e : exit the script if any statement returns a non-true return value - enabled
	# This file is/was autogenerated by ${0}; don't modify manually
AUTOGEN_INCLUDES_FOOTER

echo "done."