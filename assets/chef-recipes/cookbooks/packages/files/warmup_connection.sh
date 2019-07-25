#!/bin/bash

default_routers=$(ip route list match default | awk '{print $3}')
for router in ${default_routers}
do
  ping -c 2 ${router}
done
