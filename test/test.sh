#!/bin/sh

if ! vagrant box list | grep debian-squeeze-64 >/dev/null; then
  vagrant box add debian-squeeze-64 ../debian-squeeze-64.box
fi

vagrant up
vagrant ssh
