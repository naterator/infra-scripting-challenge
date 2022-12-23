# Infrastructure Scripting Challenge

## Assumptions

- Sophisticated error handling will be implemented at a later time.
- The prune and test scripts are ran on a Linux or macOS host.
- The environment has AWS credentials that are valid for use by `awscli` and `boto3`.
- The API of AWS IAM and S3 is available.
- The host running the prune and test scripts has network connectivity to the internet.
- There are always at least a few deployments in the S3 bucket (ie, this tool hasn't been tested against a bucket with 0 to 2 deployments).

## Question Responses

### Where should we run this script?

There are many options, but here are a few ideas:

- Kubernetes `cronjob`
- Nomad job
- AWS CloudWatch Events triggering a Lambda job
- EC2 instance via a `systemd` `timer`

### How should we test the script before running it production?

Use the provided [test.sh](https://github.com/naterator/scaling-guacamole/blob/main/test.sh) wrapper, which:

- Creates a temporary S3 bucket.
- Generates test deployment directories and their contents.
- Copies the test deployment directories to the S3 bucket with distinct timestamps.
- Runs the [s3-prune.py](https://github.com/naterator/scaling-guacamole/blob/main/s3-prune.py) deployment S3 bucket pruning tool.
- Deletes the S3 bucket and its contents.

### If we want to add an additional requirement of deleting deploys older than 30 days while keeping X deployments. What additional changes would you need to make in the script?

In the [s3-prune.py](https://github.com/naterator/scaling-guacamole/blob/main/s3-prune.py) script, you'd need to update [the logic at the point where it selects which deployments to delete](https://github.com/naterator/scaling-guacamole/blob/main/s3-prune.py#L46) from:

```python
deployments_to_delete = deployments_sorted[count:]
```

...to something like:

```python
thirty_days_ago = datetime.now() + timedelta(days=-30)
deployments_to_keep = deployments_sorted[:count-1]
deployments_to_delete_1 = deployments_sorted[count:]
deployments_to_delete_2 = filter(lambda d: d < thirty_days_ago, deployments_unsorted)
deployments_to_delete_comb = set(deployments_to_delete_1 + deployments_to_delete_2)
deployments_to_delete = [i for i in deployments_to_delete_comb if i not in deployments_to_keep]
```

_NOTE: The aforementioned code has not been tested._
