#!/bin/bash

# for more information, see http://alvarogarcia7.github.io/blog/2016/02/14/two-persons-involved-in-a-git-commit/

echo "as this might contain personal information, we only show how to do it. Copy/paste with correct data"

echo "export GIT_COMMITTER_NAME=person_name"
echo "export GIT_COMMITTER_EMAIL=person_email"

echo "to check the last commits: git log --format=\"%aN %aE %cN %cE"\   "
