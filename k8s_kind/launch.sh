#!/bin/bash
set -x
set -e
export JARVICE_APP_NAME=${9}
export JARVICE_TARGET_MACHINE=${10}
export JARVICE_API_URL=${2}
export JARVICE_USER=${4}
export JARVICE_API_KEY=${6}
export JARVICE_VAULT=${8}

cat << EOF > submit.json
{
  "app": "$JARVICE_APP_NAME",
  "staging": false,
  "checkedout": false,
  "application": {
    "command": "custom",
    "geometry": "1904x841",
    "parameters": {
      "color": "blue"
    }
  },
  "machine": {
    "type": "$JARVICE_TARGET_MACHINE",
    "nodes": 1
  },
  "vault": {
    "name": "$JARVICE_VAULT",
    "readonly": false,
    "force": false
  },
  "user": {
    "username": "$JARVICE_USER",
    "apikey": "$JARVICE_API_KEY"
  }
}
EOF

cat submit.json

# Submit batch job
curl -H 'Content-Type: application/json' -X POST -d @submit.json ${JARVICE_API_URL}/jarvice/submit 1> answer.json 2>error
if [ $? != 0 ]; then
    echo "Error, could not reach API endpoint"
    cat error
    exit 1
fi
cat answer.json
cat error

JOB_NAME=$(cat answer.json | jq -r .name)
JOB_NUMBER=$(cat answer.json | jq -r .number)

# Iterate and wait for job to complete
job_success=1
for (( c=1; c<=30; c++ ))
do
   sleep 10s
   echo "Getting job status..."
   curl -X GET "${JARVICE_API_URL}/jarvice/status?username=${JARVICE_USER}&apikey=${JARVICE_API_KEY}&number=${JOB_NUMBER}" 1>answer.json 2>error
   if [ $? != 0 ]; then
      echo "Error, could not reach API endpoint"
      cat error
      exit 1
   fi
   cat answer.json
   cat error
   JOB_STATUS=$(cat answer.json | jq -r .[].job_status)
   echo ${JOB_STATUS}
   if [ ${JOB_STATUS} == "COMPLETED" ]; then
     echo "Job completed"
     job_success=0
     break
   fi
done

if [ $job_success != 0 ]; then
  echo "JOB failed"
  exit 1
fi

# Get output
curl -X GET "${JARVICE_API_URL}/jarvice/output?username=${JARVICE_USER}&apikey=${JARVICE_API_KEY}&number=${JOB_NUMBER}" 1>answer.json 2>error
if [ $? != 0 ]; then
    echo "Error, could not reach API endpoint"
    cat error
    exit 1
fi
echo "JOB output"
cat answer.json
cat error

# Check the job was a success
cat answer.json | grep '^blue$'
if [ $? != 0 ]; then
    job_status="FAILED"
else
    job_status="SUCCESS"
fi
echo "JOB status: $job_status"

