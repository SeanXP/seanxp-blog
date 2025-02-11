#!/bin/bash
#################################################################
#   Copyright (C) 1998-2025 Tencent Inc. All rights reserved.
#
#   > File Name:        < update.sh >
#   > Author:           < Sean Guo >
#   > Mail:             < seanguo@tencent.com >
#   > Created Time:     < 2025/02/12 >
#   > Description:
#################################################################
set -o nounset
set -o errexit
set -o pipefail
#set -o xtrace
npm run algolia
