#!/bin/bash
apt-get clean
umount /*
export HISTSIZE=0
rm -rf ~/.bash_history
exit