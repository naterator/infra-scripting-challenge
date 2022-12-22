#!/bin/sh

# adjustable values
AWS="aws"
TEST_DEPLOY_NAMES="
deployhash112
dsfsfsl9074
delkjlkploy3
dsfff1234321
klljkjkl123
"

# for debug purposes
BUCKET_EXISTS=0

# see if our AWS env creds work
ARN=$($AWS sts get-caller-identity 2>&1 | grep -i arn|awk -F\" '{print$4}')
if [ ! -z $ARN ]; then
  printf "Executing as AWS ARN '$ARN'...\n"
else
  printf "ERROR: Unable to authenticate to AWS. Exiting...\n"
  exit 130
fi

# dynamically-generated values
BUCKET_NAME=$(head -c 4096 /dev/urandom | sha1sum | awk '{print$1}')
TEMP_DIR="$(mktemp -d)"

printf "Creating test deployment bucket s3://$BUCKET_NAME..."

# create the bucket
if [ $BUCKET_EXISTS -ne 1 ]; then
  $AWS s3api create-bucket \
    --bucket $BUCKET_NAME \
    --acl private \
    --region us-east-1 \
    --create-bucket-configuration LocationConstraint=us-west-2 >/dev/null 2>&1
fi

# fail if we didn't create the bucket
if [ $? -eq 0 ]; then
  printf "DONE!\n"
else
  printf "FAILED! Exiting...\n"
  exit 127
fi

printf "Generating test deployment files..."

# create the test data for the bucket
for DEP_NAME in $TEST_DEPLOY_NAMES; do
  DEP_DIR="${TEMP_DIR}/$DEP_NAME"
  mkdir -p "${DEP_DIR}/css" "${DEP_DIR}/image"
  i="${DEP_DIR}/index.html"
  printf "<html><head><link rel=\"stylesheet\" href=\"css/font.css\">" > "$i"
  printf "</head><body><h1>Deployment: $DEP_NAME</h1></body></html>\n" >> "$i"
  printf 'body { font-family: Sans-serif; background: 
    url(../image/hey.png); }\n' > "${DEP_DIR}/css/font.css"
  printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC
    0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=' |
    base64 -d > "${DEP_DIR}/image/hey.png"
done

printf "DONE!\n"

printf "Uploading test deployment files to s3://$BUCKET_NAME..."

# copy the deployments to the bucket
# we could do this with:
# $ $AWS s3 sync "${TEMP_DIR}" "s3://${BUCKET_NAME}" >/dev/null 2>&1
# ...but we want the deploys to have different timestamps
# so here we go...
for DEP_NAME in $TEST_DEPLOY_NAMES; do
  DEP_DIR="${TEMP_DIR}/$DEP_NAME"
  for FN in index.html css/font.css image/hey.png; do
    $AWS s3 cp "${DEP_DIR}/$FN" "s3://$BUCKET_NAME/$DEP_NAME/$FN" >/dev/null 2>&1
  done
  sleep 3
done

# fail if we didn't sync the bucket
if [ $? -eq 0 ]; then
  printf "DONE!\n"
else
  printf "FAILED! Exiting...\n"
  exit 128
fi

printf "Deleting local temporary data directory..."

# delete the temp directory data
rm -fr "${TEMP_DIR}"

printf "DONE!\n"

printf "Running s3-prune.py...\n=== START s3-prune.py OUTPUT ===\n"

# run the script
python3 s3-prune.py -c 3 -b $BUCKET_NAME

printf "=== END s3-prune.py OUTPUT ===\nDONE!\n"

printf "Deleting test deployment bucket s3://$BUCKET_NAME..."

# delete the test bucket
$AWS s3 rm "s3://${BUCKET_NAME}" --recursive >/dev/null 2>&1 && \
  sleep 2 && \
  $AWS s3api delete-bucket --bucket $BUCKET_NAME --region us-east-1 >/dev/null 2>&1

# fail if we didn't delete the bucket
if [ $? -eq 0 ]; then
  printf "DONE!\n"
else
  printf "FAILED! Exiting...\n"
  exit 129
fi

exit 0
