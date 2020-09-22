#!/bin/bash

set -xe

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# -----------------------------------------------------------------------------

mkdir -p $DIR/simple-script-1

cat > $DIR/simple-script-1/application.py <<END
import os

print("Right now I am here - {}".format(os.getcwd()))

content = os.listdir('.')
print("There are {} elements in this directory".format(len(content)))
for element in content:
    print(element)
END

cat > $DIR/simple-script-1/Dockerfile <<END
FROM python:3.7

COPY application.py application.py

ENTRYPOINT ["python3", "application.py"]
END

# --------------------------------------------------------------------------

mkdir -p $DIR/mount-directory-2

cat > $DIR/mount-directory-2/application.py <<END
import os
import sys

target_dir = sys.argv[1]

print("Observe directory - {}".format(target_dir))

content = os.listdir(target_dir)
print("There are {} elements in this directory".format(len(content)))
for element in content:
    print(element)
END

cat > $DIR/mount-directory-2/Dockerfile <<END
FROM python:3.7

COPY application.py application.py

ENTRYPOINT ["python3", "application.py"]
END

# ----------------------------------------------------------------------

mkdir -p $DIR/ports-3

cat > $DIR/ports-3/Dockerfile <<END
FROM python:3.7

RUN mkdir /sync-folder

WORKDIR /sync-folder

ENTRYPOINT ["python3", "-m", "http.server", "--bind", "0.0.0.0", "8080"]
END