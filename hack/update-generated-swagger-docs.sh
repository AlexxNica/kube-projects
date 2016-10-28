#!/bin/bash

# Copied from
# https://github.com/kubernetes/kubernetes/blob/92cb90fc5d118ed5c892f425ed1ded5290894db5/hack/update-generated-swagger-docs.sh
# and modified for this project

set -o errexit
set -o nounset
set -o pipefail

source "$(dirname "${BASH_SOURCE}")/lib/init.sh"

# Generates types_swagger_doc_generated file for the given group version.
# $1: Name of the group version
# $2: Path to the directory where types.go for that group version exists. This
# is the directory where the file will be generated.
gen_types_swagger_doc() {
  local group_version=$1
  local TMPFILE="/tmp/types_swagger_doc_generated.$(date +%s).go"

  echo "Generating swagger type docs for ${group_version}"

  echo "package ${group_version##*/}" > "$TMPFILE"
  cat >> "$TMPFILE" <<EOF

// This file contains a collection of methods that can be used from go-restful to
// generate Swagger API documentation for its models. Please read this PR for more
// information on the implementation: https://github.com/emicklei/go-restful/pull/215
//
// TODOs are ignored from the parser (e.g. TODO(andronat):... || TODO:...) if and only if
// they are on one line! For multiple line or blocks that you want to ignore use ---.
// Any context after a --- is ignored.
//
// Those methods can be generated by using hack/update-generated-swagger-docs.sh

// AUTO-GENERATED FUNCTIONS START HERE
EOF

  ${genswaggertypedocs} -s \
    "${group_version}/types.go" \
    -f - \
    >>  "$TMPFILE"

  echo "// AUTO-GENERATED FUNCTIONS END HERE" >> "$TMPFILE"

  gofmt -w -s "$TMPFILE"
  mv "$TMPFILE" "${group_version}/types_swagger_doc_generated.go"
}

GROUP_VERSIONS=(${ALL_GROUP_VERSIONS})

# To avoid compile errors, remove the currently existing files.
find . -not \( \( -wholename '*/vendor/*' -o -wholename '*/_tmp/*' \) -prune \) -name 'types_swagger_doc_generated.go' -exec rm {} \;

make -C "${OS_ROOT}" WHAT=vendor/k8s.io/kubernetes/cmd/genswaggertypedocs

# Find binary
genswaggertypedocs="$(os::build::find-binary genswaggertypedocs ${OS_ROOT})"

if [[ ! -x "$genswaggertypedocs" ]]; then
  {
    echo "It looks as if you don't have a compiled genswaggertypedocs binary"
  } >&2
  exit 1
fi

# Now generate
for group_version in "${GROUP_VERSIONS[@]}"; do
  gen_types_swagger_doc "${group_version}"
done