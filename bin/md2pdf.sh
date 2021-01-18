## https://github.com/alvarogarcia7/markdown-to-pdf

set euxo -pipefail

file="$1"

docker run -it -v $(pwd):/data markdown-to-pdf ./node_modules/.bin/markdown-pdf /data/"$file" -o /data/"$file.pdf"

