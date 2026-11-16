#!/bin/bash
# Pi 5 に gamma の自動起動を入れる。この pi/ を Pi にコピーして sudo で実行する:
#   scp -r pi kota0314@raspberry-pi-5-8:/tmp/ && ssh kota0314@raspberry-pi-5-8 sudo bash /tmp/pi/install.sh
# やること: スクリプトとユニットの設置、beta のサービス（ros2_launch.service）の無効化、
# cloud-init の無効化（apt upgrade 後の再起動で SSH のホスト鍵が作り直されるのを防ぐ）、サービスの有効化と起動
set -e
cd "$(dirname "$0")"
install -m 755 gamma_launch.sh /usr/local/bin/gamma_launch.sh
install -m 644 gamma_launch.service /etc/systemd/system/gamma_launch.service
systemctl daemon-reload
if systemctl list-unit-files ros2_launch.service >/dev/null 2>&1; then
  systemctl disable --now ros2_launch.service || true  # beta の自動起動。ファイルは残す
fi
touch /etc/cloud/cloud-init.disabled
systemctl enable --now gamma_launch.service
sleep 3
systemctl --no-pager --lines=0 status gamma_launch.service || true
