#!/bin/sh

set -e
set -x

if [ -z "$INPUT_SOURCE_FOLDER_IGNORE" ]; then
  echo "Source folder must be defined"
  exit 1
fi

if [ "$INPUT_DESTINATION_HEAD_BRANCH" = "main" ] || [ "$INPUT_DESTINATION_HEAD_BRANCH" = "master" ]; then
  echo "Destination head branch cannot be 'main' or 'master'"
  exit 1
fi

if [ -z "$INPUT_PULL_REQUEST_REVIEWERS" ]; then
  PULL_REQUEST_REVIEWERS=$INPUT_PULL_REQUEST_REVIEWERS
else
  PULL_REQUEST_REVIEWERS='-r '$INPUT_PULL_REQUEST_REVIEWERS
fi

if [ -n "$INPUT_FILE_IGNORES" ]; then
  IFS=',' read -ra IGNORE_LIST <<< "$INPUT_FILE_IGNORES"
fi

CLONE_DIR=$(mktemp -d)

echo "Setting git variables"
export GITHUB_TOKEN=$API_TOKEN_GITHUB
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"

echo "Cloning destination git repository"
git clone "https://$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

echo "Copying contents to git repo"
mkdir -p "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/"

# Copy files excluding ignored files
for FILE in $(find "$INPUT_SOURCE_FOLDER_IGNORE" -type f); do
  IGNORE=false
  FILE_BASENAME=$(basename "$FILE")
  for IGNORE_FILE in "${IGNORE_LIST[@]}"; do
    if [ "$IGNORE_FILE" = "$FILE_BASENAME" ]; then
      IGNORE=true
      break
    fi
  done
  if [ "$IGNORE" = false ]; then
    DEST_FILE="$CLONE_DIR/$INPUT_DESTINATION_FOLDER/${FILE#$INPUT_SOURCE_FOLDER_IGNORE/}"
    mkdir -p "$(dirname "$DEST_FILE")"
    cp "$FILE" "$DEST_FILE"
  fi
done

cd "$CLONE_DIR"
git checkout -b "$INPUT_DESTINATION_HEAD_BRANCH"

echo "Adding git commit"
git add .
if git status | grep -q "Changes to be committed"; then
  git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
  echo "Pushing git commit"
  git push -u origin HEAD:$INPUT_DESTINATION_HEAD_BRANCH
  echo "Creating a pull request"
  gh pr create -t "[$INPUT_SYMBOL] [$(date '+%d-%m-%Y %H:%M:%S')] Changes from main" \
               -b "[$INPUT_SYMBOL] - Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA" \
               -B "$INPUT_DESTINATION_BASE_BRANCH" \
               -H "$INPUT_DESTINATION_HEAD_BRANCH" \
               $PULL_REQUEST_REVIEWERS
else
  echo "No changes detected"
fi
