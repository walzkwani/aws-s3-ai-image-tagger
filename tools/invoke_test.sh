#!/usr/bin/env bash
set -euo pipefail
FUNC_NAME="${1:-s3-ai-image-tagger-tagger}"
aws lambda invoke --function-name "$FUNC_NAME" --payload '{"Records":[]}' out.json && cat out.json && rm out.json
