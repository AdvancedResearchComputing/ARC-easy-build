#!/bin/bash

newgrp arc.arcadm
umask 002
module reset
module unload site/tinkercliffs/easybuild/setup
module load site/tinkercliffs/easybuild/arc.arcadm
module load EasyBuild
