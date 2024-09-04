#!/usr/bin/env bash
#
# Copyright 2024 - The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

# This script was created to fix up some issues with the android.jar
# files for `module-lib` and `system-server` in historical releases
# 30 to 34. Modifying binary files is potentially dangerous so this was
# created and put under version control to make it easy for someone to
# verify the results if needed.

# The basic function is:
# * Save away a copy of the original android.jar, if not already
#   present.
# * Create a new android.jar that combines the original android.jar
#   with the jars from the missing mainline modules.
# * Add a README.md to explain what happened.

SOURCE=${BASH_SOURCE[0]}
SOURCE_DIR=$(dirname $SOURCE)

# Change directory to top.
cd $SOURCE_DIR/../..
TOP=$PWD
echo "Changed directory to $TOP; all paths are relative to that."
SOURCE_DIR="prebuilts/sdk"

if [[ $# == 0 ]]; then
  echo "$SOURCE <version>+" >&2
  exit 1
fi

VERSIONS=$@
SURFACES=(
  module-lib
  system-server
)

function find_updatable_modules() {
  typeset SURFACE=$1

  # Scan the prebuilts/sdk numbered directories in the specified surface for
  # jars. Exclude the following jars:
  # 1. Any jar starting with android. That will exclude android.net.ipsec.ike
  #    as well but that will be added explicitly below.
  # 2. core-for-system-modules.jar as that is not an updatable module.
  # 3. art as while that is an updatable module it must already be included in
  #    the android.jar otherwise it would be unusable.
  # 4. runtime-i18n as that is not updatable and must be included as it is
  #    needed by art.
  find $SOURCE_DIR -maxdepth 3 -type f -name \*.jar | \
    grep -vE "/(android.*|core-for-system-modules|art|runtime-i18n)\.jar$" | \
    grep -E "/[1-9][0-9]*/$SURFACE" | \
    xargs -n1 basename | \
    sort -u
}

# Add module-lib modules that do not fit into the standard naming pattern.
MODULE_LIB_MODULES=(
  android.net.ipsec.ike
)

# Add additional module-lib updatable modules.
mapfile -O 1 -t MODULE_LIB_MODULES < <(find_updatable_modules module-lib)

# Find all the system-server updatable modules.
mapfile -t SYSTEM_SERVER_MODULES < <(find_updatable_modules system-server)

for VERSION in $VERSIONS
do
  if ((VERSION < 30)); then
    echo "$SOURCE: invalid version: $VERSION must be >= 30" >&2
    exit 1
  fi

  VERSION_DIR=$SOURCE_DIR/$VERSION
  if [ ! -d $VERSION_DIR ]; then
    echo "$SOURCE: invalid version: $VERSION" >&2
    exit 1
  fi

  for SURFACE in ${SURFACES[@]}
  do
    SURFACE_DIR=$VERSION_DIR/$SURFACE
    if [ ! -d $SURFACE_DIR ]; then
      echo "$SOURCE: $SURFACE_DIR does not exist" >&2
      exit 1
    fi

    MODULE_LIB_DIR=$VERSION_DIR/module-lib


    ANDROID_JAR=$SURFACE_DIR/android.jar

    NEW_JAR=$SURFACE_DIR/android-plus-updatable.jar
    rm -f $NEW_JAR

    echo
    echo "Merging the following jars into $NEW_JAR:"
    echo "  $ANDROID_JAR"
    JARS=$ANDROID_JAR

    # Add all the module-lib jars to the list of jars to merge.
    # These are always added, even for the system-server as the
    # system-server directory only includes service-* modules but the
    # system-server API surface is a super set of module-lib so should
    # include everything that is in the module-lib updatable modules
    # too.
    for MODULE in ${MODULE_LIB_MODULES[@]}
    do
      MODULE_JAR=$MODULE_LIB_DIR/$MODULE
      if [ -f $MODULE_JAR ]; then
        echo "  $MODULE_JAR"
        JARS="$JARS $MODULE_JAR"
      fi
    done

    if [[ $SURFACE == "system-server" ]]; then
      # Add all the system-server jars to the list of jars to merge.
      for MODULE in ${SYSTEM_SERVER_MODULES[@]}
      do
        MODULE_JAR=$SURFACE_DIR/$MODULE
        if [ -f $MODULE_JAR ]; then
          echo "  $MODULE_JAR"
          JARS="$JARS $MODULE_JAR"
        fi
      done
    fi

    # Merge all the zips ignoring duplicates (should only be
    # META-INF/MANIFEST.MF) created a sorted (-s) jar (-j).
    merge_zips -ignore-duplicates -j -s $NEW_JAR $JARS

    README=$SURFACE_DIR/README.md
    cat > $README <<EOF
## Updated since finalization

The android-plus-updatable.jar has been added to this directory after
finalization as the android.jar in this directory does not include updatable
modules. That is because doing so in the source would lead to dependency cycles
and the prebuilts have to match the source structure so that apps can build
against either prebuilts or sources.

The lack of updatable modules in android.jar caused problems for the
api-version.xml generation as that requires a single jar containing all the
APIs for each surface of each API version. See b/337836752 for more
information.
EOF

    # Adding the new files to git.
    (cd $SOURCE_DIR; git add ${NEW_JAR#$SOURCE_DIR/} ${README#$SOURCE_DIR/})

  done
done
