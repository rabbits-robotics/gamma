#!/bin/bash
# gamma の自動起動スクリプト。systemd の gamma_launch.service から呼ばれる（/usr/local/bin に置く）。
# 手で試すときもこれをそのまま実行すればよい。ログは journalctl -u gamma_launch -f
set -e
source /opt/ros/jazzy/setup.bash
source "${HOME}/rabbits_ws/install/setup.bash"
export ROS_DOMAIN_ID=42
exec ros2 launch rabbits_bringup gamma.launch.py \
  device:=/dev/serial/by-id/usb-FTDI_FT230X_Basic_UART_DP04TJ8I-if00-port0 \
  input:=gamepad gamepad:=onefun_ps4_native rviz:=false
