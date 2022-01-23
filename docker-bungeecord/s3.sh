#!/bin/bash

cd /server && s3cmd get --recursive --force s3://proxy-volume
