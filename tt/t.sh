#!/bin/bash
# mirror test
rm -f /etc/apt/sources.list
# copy origin
cp -Pv /etc/apt/sources.list.bk /etc/apt/sources.list
sudo sed -i 's@http://.*ubuntu.com@https://mirrors.ustc.edu.cn@g' /etc/apt/sources.list
