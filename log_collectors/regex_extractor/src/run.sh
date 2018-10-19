#!/usr/bin/env bash
#---------------------------------------------------------------#
#                                                               #
# IBM Confidential                                              #
# OCO Source Materials                                          #
#                                                               #
# (C) Copyright IBM Corp. 2001, 2017                            #
#                                                               #
# The source code for this program is not published or          #
# otherwise divested of its trade secrets, irrespective of      #
# what has been deposited with the U.S. Copyright Office.       #
#                                                               #
#---------------------------------------------------------------#

while [ ! -d ${LOG_DIR} ]
do
  sleep 1
done

export LEARNER_ID=$((${DOWNWARD_API_POD_NAME##*-} + 1)) ;
echo "$EM_DESCRIPTION" > ${LOG_DIR}/evaluation_metrics_description.yaml
export EM_DESCRIPTION="$LOG_DIR/evaluation_metrics_description.yaml"
echo "* * * * * AWS_ACCESS_KEY_ID=$RESULT_STORE_USERNAME AWS_SECRET_ACCESS_KEY=$RESULT_STORE_APIKEY \
timeout -s 3 20 /usr/local/bin/aws --endpoint-url=$RESULT_STORE_AUTHURL s3 sync \

$LOG_DIR s3://$RESULT_STORE_OBJECTID"> crontab.txt && \
echo "* * * * * (sleep 30 && AWS_ACCESS_KEY_ID=$RESULT_STORE_USERNAME AWS_SECRET_ACCESS_KEY=$RESULT_STORE_APIKEY \
 timeout -s 3 20 /usr/local/bin/aws --endpoint-url=$RESULT_STORE_AUTHURL s3 sync \
 $LOG_DIR s3://$RESULT_STORE_OBJECTID)">> crontab.txt && crontab crontab.txt && rm -f crontab.txt
service cron start
python3 extract_from_log.py
echo "Saving final logs for $TRAINING_ID : " && time AWS_ACCESS_KEY_ID=$RESULT_STORE_USERNAME \
AWS_SECRET_ACCESS_KEY=$RESULT_STORE_APIKEY timeout -s 3 20 /usr/local/bin/aws --endpoint-url=$RESULT_STORE_AUTHURL \
s3 sync $LOG_DIR s3://$RESULT_STORE_OBJECTID
ERROR_CODE=$?
echo "echo aws s3 exit code $ERROR_CODE"
echo "Writing $ERROR_CODE to $JOB_STATE_DIR" >&2
echo $ERROR_CODE > $JOB_STATE_DIR/lc.exit

echo "done writing state file to nfs"

# exit $ERROR_CODE
sleep 180

echo "exiting log-collector instead of being killed"

# this probably won't execute?
exit $ERROR_CODE