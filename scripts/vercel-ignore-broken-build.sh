#!/bin/bash
# CargoDek deployment safety gate.
# Exit 0 = skip the Vercel deployment.
# Exit 1 = allow the Vercel deployment to continue.

node scripts/validate-frontend.js
status=$?

if [ "$status" -eq 0 ]; then
  echo "CargoDek frontend validation passed. Allowing deployment."
  exit 1
fi

echo "CargoDek frontend validation failed. Skipping this deployment so the last working production version remains live."
exit 0
