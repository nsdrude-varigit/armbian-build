#!/bin/bash

set -e

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <kernel-version>" >&2
	exit 1
fi

kernelver="$1"
kernel_build="/lib/modules/${kernelver}/build"

echo "Building NXP Wi-Fi driver"
echo "Kernel version: ${kernelver}"
echo "Kernel build:   ${kernel_build}"
echo "Source:         ${PWD}"

exec make \
	-C "${kernel_build}" \
	M="${PWD}" \
	KERNELDIR="${kernel_build}" \
	modules
