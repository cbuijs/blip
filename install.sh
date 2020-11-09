#!/bin/sh

opkg update

opkg install bash
opkg install grep coreutils-tr gawk coreutils-paste coreutils-sort coreutils-date wget
opkg install iptables-mod-tarpit


