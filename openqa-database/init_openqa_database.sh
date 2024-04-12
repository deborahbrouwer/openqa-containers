#!/bin/bash

set -e
UPDATE job_groups SET build_version_sort = false;
UPDATE job_groups SET id = 1 WHERE name = 'fedora';
UPDATE job_groups SET size_limit_gb = 500 WHERE name = 'fedora';