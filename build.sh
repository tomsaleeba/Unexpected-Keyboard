#!/bin/bash
set -euo pipefail
cd $(dirname "$0")
docker run \
  --rm \
  -it \
  -v $PWD:/app \
  -w /app \
  -u 1000:1000 \
  circleci/android:api-30 \
  bash -c make
