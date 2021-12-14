#!/bin/bash
 echo Destroing $1 ...
 terraform destroy -target google_compute_instance_from_template.$1 -auto-approve > tf_manual.log
 echo Recreating $1 ...
 terraform apply -auto-approve >> tf_manual.log
 echo Done