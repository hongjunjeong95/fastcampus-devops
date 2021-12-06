#!/usr/bin/env bash

set -euf -o pipefail

apt-get install -y \
  build-essential \
  software-properties-common
# software-properties-common : *PPA를 추가하거나 제거할 때 사용한다

apt-get install -y htop jq awscli curl wget git
