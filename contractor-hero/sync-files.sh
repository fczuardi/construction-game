#!/bin/bash

GODOT_PROJECT_FOLDER="../../gamedev/portraitgame01/"

# always duplicate this script plus README and TODO in the root of
# the monorepo regardless of other files
cp ${GODOT_PROJECT_FOLDER}README.md .
cp ${GODOT_PROJECT_FOLDER}TODO.md .
cp ${GODOT_PROJECT_FOLDER}sync-files.sh .

CMD="rsync --dry-run \
  --archive --delete --verbose --progress \
  --exclude=.godot/ \
  --exclude=*.import \
  --exclude=*.fbx \
  --exclude=.editorconfig \
  --exclude=*.cfg \
  --exclude=android/ \
  --exclude=textures/ \
  --exclude=icons/  \
  --exclude=fonts/*.ttf \
  --include=fonts/*.html \
  --exclude=.jj/ \
  $GODOT_PROJECT_FOLDER
  ./contractor-hero"

eval $CMD
echo review the changes above and execute the command below to sync:
echo ${CMD//"--dry-run"}
