#!/bin/sh

set -e
set -x

if [ -z "$INPUT_SOURCE_FOLDER" ]
then
  echo "Source folder must be defined"
  exit 1
fi

if [ "$INPUT_DESTINATION_HEAD_BRANCH" = "main" ] || [ "$INPUT_DESTINATION_HEAD_BRANCH" = "master" ]
then
  echo "Destination head branch cannot be 'main' or 'master'"
  exit 1
fi

if [ -z "$INPUT_PULL_REQUEST_REVIEWERS" ]
then
  PULL_REQUEST_REVIEWERS="$INPUT_PULL_REQUEST_REVIEWERS"
else
  PULL_REQUEST_REVIEWERS="-r $INPUT_PULL_REQUEST_REVIEWERS"
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
cp -R "$INPUT_SOURCE_FOLDER" "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/"
cd "$CLONE_DIR"
git checkout -b "$INPUT_DESTINATION_HEAD_BRANCH"

echo "Adding git commit"

exclude_files=("file1.txt" "assets/ben.js")

add_command="git add ."

for file in "${exclude_files[@]}"; do
    add_command+=" --exclude=$file"
done

eval "$add_command"

if git status | grep -q "Changes to be committed"
then
  git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
  echo "Pushing git commit"
  git push -u origin HEAD:$INPUT_DESTINATION_HEAD_BRANCH
  echo "Creating a pull request"
  gh pr create -t "[$INPUT_SYMBOL] [$(date '+%d-%m-%Y %H:%M:%S')] $INPUT_MESSAGE" \
               -b "[$INPUT_SYMBOL] - Beep Boop - Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA" \
               -B "$INPUT_DESTINATION_BASE_BRANCH" \
               -H "$INPUT_DESTINATION_HEAD_BRANCH" \
               $PULL_REQUEST_REVIEWERS
else
  echo "No changes detected"
fi
