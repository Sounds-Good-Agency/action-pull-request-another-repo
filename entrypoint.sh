#!/bin/sh

set -e
set -x

# installing curl
# apt-get update && apt-get install curl
echo "Running entry point script..."
echo "Source folder: $INPUT_SOURCE_FOLDER"
echo "Destination repo: $INPUT_DESTINATION_REPO"
echo "Destination folder: $INPUT_DESTINATION_FOLDER"
echo "Files to exclude: $INPUT_FILES_TO_EXCLUDE"

if [ -z "$INPUT_SOURCE_FOLDER" ]
then
  echo "Source folder must be defined"
  return -1
fi

if [ $INPUT_DESTINATION_HEAD_BRANCH == "main" ] || [ $INPUT_DESTINATION_HEAD_BRANCH == "master"]
then
  echo "Destination head branch cannot be 'main' or 'master'"
  return -1
fi

if [ -z "$INPUT_PULL_REQUEST_REVIEWERS" ]
then
  PULL_REQUEST_REVIEWERS=$INPUT_PULL_REQUEST_REVIEWERS
else
  PULL_REQUEST_REVIEWERS='-r '$INPUT_PULL_REQUEST_REVIEWERS
fi

CLONE_DIR=$(mktemp -d)

echo "Setting git variables"
export GITHUB_TOKEN=$API_TOKEN_GITHUB
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"

echo "Cloning destination git repository"
# git clone "https://$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

# make curl to https://api.github.com/repos/expedo-store/pulls/40/files with $API_TOKEN_GITHUB
# curl https://api.github.com/repos/expedo-store/pulls/40/files
# echo 'curling'
# curl -H "Authorization: token $API_TOKEN_GITHUB" https://api.github.com/repos/expedo-store/pulls/40/files

echo "Cloning to $INPUT_DESTINATION_BASE_BRANCH"
git clone -b $INPUT_DESTINATION_BASE_BRANCH "https://$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

echo "Copying contents to git repo"
mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER/
cp -R $INPUT_SOURCE_FOLDER "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/"
cd "$CLONE_DIR"
git checkout -b "$INPUT_DESTINATION_HEAD_BRANCH"

echo "$INPUT_BODY"
echo "Adding git commit"
# // files-to-exclude
echo $INPUT_FILES_TO_EXCLUDE
# git add . $INPUT_FILES_TO_EXCLUDE

# for file in $INPUT_DESTINATION_FILES; do
#     echo $file
#     git add $file
# done

echo 'here is the list of files'
echo $INPUT_DESTINATION_FILES

for file in $INPUT_DESTINATION_FILES; do
  git add $file
done

git status

if git status | grep -q "Changes to be committed"
then
  git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
  echo "Pushing git commit"
  git push -u origin HEAD:$INPUT_DESTINATION_HEAD_BRANCH
  echo "Creating a pull request"
  gh pr create -t "[$INPUT_SYMBOL] [$(date '+%d-%m-%Y %H:%M:%S')] $INPUT_MESSAGE" \
               -b "$INPUT_BODY"$'\n\n\n'"From: https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA" \
               -B $INPUT_DESTINATION_BASE_BRANCH \
               -H $INPUT_DESTINATION_HEAD_BRANCH \
                  $PULL_REQUEST_REVIEWERS
else
  echo "No changes detected"
fi
