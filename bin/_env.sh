## Setting the java version
## Quickly check the current version before changing versions

java -version 2>&1|grep -q "11\.0\.1" || sdk use java "11.0.1-zulu"

## Setting your email for a specific folder (i.e., client-specific)
export GIT_COMMITTER_EMAIL="desired_email@domain.com"
export GIT_AUTHOR_EMAIL="$GIT_COMMITTER_EMAIL"
