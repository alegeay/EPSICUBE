#!/bin/bash

cd /data && s3cmd get --recursive --force s3://lobby1-volume
