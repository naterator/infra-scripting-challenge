#!/usr/bin/env python3

import boto3, click, json, sys

@click.command()
@click.option('-c', '--count', type=click.INT, required=True, 
    help='Number of deployments to keep.', envvar='S3_PRUNE_COUNT')
@click.option('-b', '--bucket', type=click.STRING, required=True, 
    help='S3 bucket containing deployments.', envvar='S3_PRUNE_BUCKET')

def run(count, bucket):
    # get an s3 client and resourcer
    s3c = boto3.client('s3')
    s3r = boto3.resource('s3')

    # head the bucket to make sure it exists and is likely accessible
    try:
        s3c.head_bucket(Bucket=bucket)
    except:
        click.echo('ERROR: Unable to lookup bucket. Exiting...', err=True)
        sys.exit(128)

    # list the bucket deployments. note that directories don't exist in S3,
    #   so we'll just use the "last modified" timestamp of index.html
    deployments_unsorted = {}
    paginator = s3c.get_paginator('list_objects_v2')
    paginator_params = {'Bucket': bucket, 'Delimiter': '/'}
    page_iterator = paginator.paginate(**paginator_params)
    for page in page_iterator:
        for cpi in page['CommonPrefixes']:
            deployment = cpi['Prefix'].rstrip('/')
            indexhtml = s3r.Object(bucket_name=bucket, key=deployment+'/index.html')
            deployments_unsorted[deployment] = indexhtml.last_modified

    # sort the deployments by datetime into a list
    deployments_sorted = [s[0] for s in sorted(
        deployments_unsorted.items(),
        reverse=True, 
        key=lambda item: item[1]
    )]

    # output the deployments that exist
    click.echo(f"deployments_sorted = {deployments_sorted}")

    # figure out the deployments to delete
    deployments_to_delete = deployments_sorted[count:]

    # output the deployments we will attempt to delete
    click.echo(f"deployments_to_delete = {deployments_to_delete}")

    # log the deployments successfully deleted
    deployments_deleted = []

    for deployment in deployments_to_delete:
        # look up the objects for the deployment to delete
        objects_to_delete = []
        paginator = s3c.get_paginator('list_objects_v2')
        paginator_params = {'Bucket': bucket, 'Prefix': deployment+'/'}
        page_iterator = paginator.paginate(**paginator_params)
        for page in page_iterator:
            for obj in page['Contents']:
                objects_to_delete.append(obj['Key'])
        
        # delete the objects for the deployment
        try:
            s3c.delete_objects(Bucket=bucket, Delete={
                    'Objects': [{
                        'Key': obj
                    } for obj in objects_to_delete]
                }
            )
            deployments_deleted.append(deployment)
        except:
            continue

    # output the deployments deleted
    click.echo(f"deployments_deleted = {deployments_deleted}")

    # remaining deployments
    deployments_remaining = \
        [i for i in deployments_sorted if i not in deployments_deleted]

    # output the deployments remaining
    click.echo(f"deployments_remaining = {deployments_remaining}")

if __name__ == '__main__':
    run()
