#!/bin/bash

qemu-system-x86_64 -enable-kvm -m 2048 -boot d -cdrom $1 -net none

