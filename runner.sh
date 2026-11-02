#!/bin/bash
set -x
echo "== host"; nproc; free -h; df -h / | tail -1; ls -l /dev/kvm || echo NO_KVM_NODE
mkdir -p /tmp/w && cd /tmp/w
# control server + tunnel first
nohup python3 $GITHUB_WORKSPACE/server.py > /tmp/w/server.log 2>&1 &
curl -sL -o cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x cloudflared
nohup ./cloudflared tunnel --no-autoupdate --url http://127.0.0.1:8077 > /tmp/w/cf.log 2>&1 &
for i in $(seq 1 60); do URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/w/cf.log | head -1); [ -n "$URL" ] && break; sleep 2; done
echo "TUNNEL=$URL"
cd $GITHUB_WORKSPACE
git config user.name "Tab for Akshay"; git config user.email "akshay.wagh@mail.tab.bot"
git checkout -q --orphan "out-$GITHUB_RUN_ID"; git rm -rq --cached . ; echo "$URL" > url.txt
{ nproc; free -h; ls -l /dev/kvm; } > host.txt 2>&1
git add url.txt host.txt; git commit -qm "url"; git push -q origin "out-$GITHUB_RUN_ID"
# kvm
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
sudo udevadm control --reload-rules; sudo udevadm trigger --name-match=kvm
ls -l /dev/kvm
export ANDROID_SDK_ROOT=$ANDROID_HOME
export ANDROID_AVD_HOME=/tmp/w/avdh; mkdir -p $ANDROID_AVD_HOME
(pip install -q uiautomator2 > /tmp/w/pip.log 2>&1 &)
SDKM=$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager
AVDM=$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager
IMG="${IMG:-system-images;android-34;google_apis_playstore;x86_64}"
yes | $SDKM --licenses > /dev/null
$SDKM "platform-tools" "emulator" "$IMG" > /tmp/w/sdk.log 2>&1; tail -3 /tmp/w/sdk.log
echo no | $AVDM create avd -n wa -k "$IMG" -d pixel_6 --force
printf 'hw.ramSize=4096\nhw.keyboard=yes\ndisk.dataPartition.size=8G\n' >> $ANDROID_AVD_HOME/wa.avd/config.ini
export PATH=$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH
setsid nohup $ANDROID_HOME/emulator/emulator -avd wa -no-window -noaudio -no-boot-anim -gpu swiftshader_indirect -no-snapshot -cores 3 -camera-back none -camera-front none > /tmp/w/emu.log 2>&1 < /dev/null &
adb wait-for-device
for i in $(seq 1 120); do [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break; sleep 5; done
echo BOOTED=$(adb shell getprop sys.boot_completed)
adb shell settings put global window_animation_scale 0; adb shell settings put global transition_animation_scale 0; adb shell settings put global animator_duration_scale 0
cd /tmp/w
if [ -z "$NOWA" ]; then curl -sL -A "Mozilla/5.0" -o wa.apk https://www.whatsapp.com/android/current/WhatsApp.apk; adb install -r -g wa.apk > /tmp/w/install.log 2>&1; cat /tmp/w/install.log; fi
touch /tmp/w/ready
END=$(( $(date +%s) + ${MINUTES:-150}*60 ))
while [ $(date +%s) -lt $END ] && [ ! -f /tmp/w/stop ]; do sleep 15; done
echo done
