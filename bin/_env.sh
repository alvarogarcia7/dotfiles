## Setting the java version
## Quickly check the current version before changing versions

java -version 2>&1|grep -q "11\.0\.1" || sdk use java "11.0.1-zulu"

