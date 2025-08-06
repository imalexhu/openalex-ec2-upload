#!/bin/bash

# Create directory structure if it doesn't exist
mkdir -p openalex-snapshot/data/works

# Download OpenAlex works data
echo "Starting download of OpenAlex works data..."
aws s3 sync s3://openalex/data/works/ openalex-snapshot/data/works/ --no-sign-request

echo "Download complete!"
