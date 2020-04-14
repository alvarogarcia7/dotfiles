#!/bin/bash

# Previous version. requires sudo
#sudo lsof -i -n -P | grep TCP

lsof -nP -iTCP | grep LISTEN

