#!/bin/bash

for res in `terraform show|grep 'resource'|grep 'google_compute_instance_from_template'|egrep 'pub|pres'|awk '{print substr($3, 2, length($3)-2)}'`
do
 echo Destroing $res ...
 terraform destroy -target google_compute_instance_from_template.$res -auto-approve > /var/log/tf_schedule.log
done
 echo Recreating resources...
 terraform apply -auto-approve >> /var/log/tf_schedule.log
 echo Done
