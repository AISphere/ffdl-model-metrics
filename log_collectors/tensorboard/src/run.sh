#!/usr/bin/env bash

export PYTHONPATH=${PYTHONPATH}:$PWD

python extract_tb.py

ERROR_CODE=$?
echo "Writing $ERROR_CODE to $JOB_STATE_DIR" >&2
echo $ERROR_CODE > $JOB_STATE_DIR/lc.exit

echo "done writing state file to nfs"

# exit $ERROR_CODE
sleep 180

echo "exiting log-collector instead of being killed"

# this probably won't execute?
exit $ERROR_CODE