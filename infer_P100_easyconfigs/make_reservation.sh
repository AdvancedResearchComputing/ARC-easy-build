#!/bin/bash

name="software_build"
mins=120

#create reservation
scontrol create reservation reservationname=$name starttime=now duration=$mins account=arcadm nodecnt=1 PartitionName=p100_dev_q

#print resulting node
scontrol show reservation $name | grep -o 'Nodes=\S*' | sed 's/.*=\(.*\)/\1/'
