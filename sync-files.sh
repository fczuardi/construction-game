#!/bin/bash

GODOT_PROJECT_FOLDER="../../gamedev/portraitgame01/"

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
  --exclude=fonts/ \
  --exclude=.jj/ \
  $GODOT_PROJECT_FOLDER
  ."

eval $CMD
echo review the changes above and execute the command below to sync:
echo ${CMD//"--dry-run"}
