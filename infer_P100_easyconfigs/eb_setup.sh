#!/bin/bash

newgrp arc.arcadm
umask 002
module reset
module unload site/infer/easybuild/setup
module load site/infer/easybuild/arc.arcadm
module load EasyBuild
