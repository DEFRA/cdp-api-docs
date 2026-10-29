#!/bin/sh

# Local copy of the api docs bucket, seeded with the test site
aws s3 mb s3://cdp-local-api-docs
aws s3 sync /test-site s3://cdp-local-api-docs
