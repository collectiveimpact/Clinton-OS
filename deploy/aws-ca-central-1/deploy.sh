#!/usr/bin/env bash
# Clinton-OS server on AWS ca-central-1. One EC2 host, Elastic IP, S3 backup bucket,
# instance role scoped to that bucket. Run from a machine with the AWS CLI signed in
# to Clinton's account. Nothing here prints or stores credentials.
#
#   ./deploy.sh brain.clinton-os.ca https://github.com/collectiveimpact/Clinton-OS.git
#
# After it finishes, point DOMAIN at the printed Elastic IP (A record) and wait for
# Caddy to issue the certificate (about a minute after DNS resolves).
set -euo pipefail
DOMAIN="${1:?domain}"; REPO_URL="${2:?repo url}"
REGION=ca-central-1; NAME=clinton-os; TYPE=${INSTANCE_TYPE:-t4g.small}
ACCT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="clinton-os-backups-$ACCT"
export AWS_DEFAULT_REGION=$REGION

echo "1. Backup bucket"
aws s3api create-bucket --bucket "$BUCKET" --create-bucket-configuration LocationConstraint=$REGION >/dev/null 2>&1 || true
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" --lifecycle-configuration '{"Rules":[{"ID":"expire-30d","Status":"Enabled","Filter":{"Prefix":"pg/"},"Expiration":{"Days":30}}]}'

echo "2. Instance role (S3 write to the bucket only)"
aws iam create-role --role-name $NAME-ec2 --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null 2>&1 || true
aws iam put-role-policy --role-name $NAME-ec2 --policy-name s3-backups --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:PutObject\",\"s3:ListBucket\"],\"Resource\":[\"arn:aws:s3:::$BUCKET\",\"arn:aws:s3:::$BUCKET/*\"]}]}"
aws iam create-instance-profile --instance-profile-name $NAME-ec2 >/dev/null 2>&1 || true
aws iam add-role-to-instance-profile --instance-profile-name $NAME-ec2 --role-name $NAME-ec2 >/dev/null 2>&1 || true
sleep 10

echo "3. Security group (80, 443 open, 22 closed, use SSM Session Manager)"
VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SG=$(aws ec2 create-security-group --group-name $NAME --description "Clinton-OS server" --vpc-id "$VPC" --query GroupId --output text 2>/dev/null || aws ec2 describe-security-groups --filters Name=group-name,Values=$NAME --query 'SecurityGroups[0].GroupId' --output text)
for p in 80 443; do aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port $p --cidr 0.0.0.0/0 >/dev/null 2>&1 || true; done
aws iam attach-role-policy --role-name $NAME-ec2 --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore >/dev/null 2>&1 || true

echo "4. Launch"
AMI=$(aws ssm get-parameter --name /aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id --query Parameter.Value --output text)
sed -e "s|__REPO_URL__|$REPO_URL|; s|__DOMAIN__|$DOMAIN|; s|__BACKUP_BUCKET__|$BUCKET|" cloud-init.yaml > /tmp/clinton-os-user-data.yaml
IID=$(aws ec2 run-instances --image-id "$AMI" --instance-type "$TYPE" --security-group-ids "$SG" --iam-instance-profile Name=$NAME-ec2 \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3","Encrypted":true,"DeleteOnTermination":false}}]' \
  --metadata-options HttpTokens=required --user-data file:///tmp/clinton-os-user-data.yaml \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},{Key=Project,Value=Clinton-OS}]" --query 'Instances[0].InstanceId' --output text)
aws ec2 wait instance-running --instance-ids "$IID"

echo "5. Elastic IP"
ALLOC=$(aws ec2 allocate-address --domain vpc --query AllocationId --output text)
aws ec2 associate-address --instance-id "$IID" --allocation-id "$ALLOC" >/dev/null
EIP=$(aws ec2 describe-addresses --allocation-ids "$ALLOC" --query 'Addresses[0].PublicIp' --output text)

echo "6. Daily EBS snapshot policy"
aws dlm create-lifecycle-policy --description "Clinton-OS daily" --state ENABLED --execution-role-arn arn:aws:iam::$ACCT:role/service-role/AWSDataLifecycleManagerDefaultRole \
  --policy-details '{"ResourceTypes":["VOLUME"],"TargetTags":[{"Key":"Project","Value":"Clinton-OS"}],"Schedules":[{"Name":"daily","CreateRule":{"Interval":24,"IntervalUnit":"HOURS","Times":["07:00"]},"RetainRule":{"Count":14},"CopyTags":true}]}' >/dev/null 2>&1 || echo "   DLM policy skipped (create AWSDataLifecycleManagerDefaultRole once in the console, then rerun this step)"

cat <<OUT

Done.
  Instance      $IID  ($TYPE, ca-central-1)
  Elastic IP    $EIP
  Backup bucket s3://$BUCKET/pg/
  Next          Create an A record: $DOMAIN -> $EIP
                Then in the desktop app: Server URL = https://$DOMAIN
  Shell         aws ssm start-session --target $IID
  Logs          sudo docker compose -f /opt/clinton-os/deploy/aws-ca-central-1/docker-compose.yml logs -f server
OUT
