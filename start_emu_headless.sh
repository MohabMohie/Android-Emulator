#!/bin/bash

BL='\033[0;34m'
G='\033[0;32m'
RED='\033[0;31m'
YE='\033[1;33m'
NC='\033[0m' # No Color

emulator_name=${EMULATOR_NAME};
hw_accel_flag="-accel off";

function enable_hardware_acceleration () {
  HW_ACCEL_SUPPORT=$(grep -E -c '(vmx|svm)' /proc/cpuinfo)
  if [[ $HW_ACCEL_SUPPORT == *"NOT"* ]]; then
    hw_accel_flag="-accel off";
  else
    echo "Enabling Hardware Acceleration"
    hw_accel_flag="-accel on";
  fi
  kvm-ok
};

function launch_emulator () {
  adb devices | grep emulator | cut -f1 | while read line; do adb -s "$line" emu kill; done

  if [ "$OSTYPE" == "macOS" ];
  then
  emulator -avd "${emulator_name}" -wipe-data -verbose -no-window -gpu swiftshader_indirect -no-snapshot -noaudio "${hw_accel_flag}" -no-boot-anim -memory 2048 -cache-size 1000 -partition-size 2048 &
  elif [ "$OSTYPE" == "Linux" ]
  then
  nohup emulator -avd "${emulator_name}" -wipe-data -verbose -no-boot-anim -no-window -gpu off "${hw_accel_flag}" -no-snapshot -memory 2048 -cache-size 1000 -partition-size 2048 &
  elif [ "$OSTYPE" == "linux-gnu" ]
  then
  nohup emulator -avd "${emulator_name}" -wipe-data -verbose -no-boot-anim -no-window -gpu off -no-snapshot -memory 2048 "${hw_accel_flag}" -cache-size 1000 -partition-size 2048 &
  fi
};

function check_emulator_status () {

printf "${G}==> ${BL}Checking device booting up status 🧐.. ${G}<==${NC}""\n"
while [[ "$(adb shell getprop sys.boot_completed 2>&1)" != 1 ]];
  do
  sleep 2
  if [ "$(adb shell getprop sys.boot_completed 2>&1)" == 1 ];
  then
     printf "${G}☞ ${BL}Device is fully booted and running!! 😀 : '$(adb shell getprop sys.boot_completed 2>&1)' ${G}☜${NC}""\n"
     adb devices -l
     adb shell input keyevent 82
     break
  else
     if [ "$(adb shell getprop sys.boot_completed 2>&1)" == "" ];
     then
     printf "${G}==> ${YE}Device is partially Booted! 😕 ${G}<==${NC}""\n"
     else
     printf  "${G}==> ${RED}$(adb shell getprop sys.boot_completed 2>&1) 😱 ${G}<==${NC}""\n"
     fi
  fi
done

};

function disable_animation() {
  adb shell "settings put global window_animation_scale 0.0"
  adb shell "settings put global transition_animation_scale 0.0"
  adb shell "settings put global animator_duration_scale 0.0"
};

function hidden_policy() {
  adb shell "settings put global hidden_api_policy_pre_p_apps 1;settings put global hidden_api_policy_p_apps 1;settings put global hidden_api_policy 1"
};

function access_emulator_with_adb() {
  if test -s /tmp/failed; then
    echo "Skip"
  else
    "adb" shell ls || true
  fi
};

function check_emulator_focus() {

  EMU_BOOTED=0
  n=0
  first_launcher=1
  echo 1 > /tmp/failed
  while [[ $EMU_BOOTED = 0 ]];do
      echo "Test for current focus"
      #adb shell dumpsys window
      CURRENT_FOCUS=$(adb shell dumpsys window 2>/dev/null | grep -i mCurrentFocus)
      echo "Current focus: ${CURRENT_FOCUS}"
      case $CURRENT_FOCUS in
      *"Launcher"*)
        if [[ $first_launcher == 1 ]]; then
          echo "Launcher seems to be ready, wait 10 sec for another popup..."
          sleep 10
          first_launcher=0
        else
          echo "Launcher is ready, Android boot completed"
          EMU_BOOTED=1
          rm /tmp/failed
        fi
      ;;
      *"Not Responding: com.android.systemui"*)
        echo "Dismiss System UI isn't responding alert"
        adb shell input keyevent KEYCODE_ENTER
        adb shell input keyevent KEYCODE_DPAD_DOWN
        adb shell input keyevent KEYCODE_ENTER
        first_launcher=1
      ;;
      *"Not Responding: com.google.android.gms"*)
        echo "Dismiss GMS isn't responding alert"
        adb shell input keyevent KEYCODE_ENTER
        first_launcher=1
      ;;
      *"Not Responding: system"*)
        echo "Dismiss Process system isn't responding alert"
        adb shell input keyevent KEYCODE_ENTER
        first_launcher=1
      ;;
      *"ConversationListActivity"*)
        echo "Close Messaging app"
        adb shell input keyevent KEYCODE_ENTER
        first_launcher=1
      ;;
      *)
        n=$((n + 1))
        echo "Waiting Android to boot 10 sec ($n)..."
        sleep 10
      ;;
      esac
  done
  echo "Android Emulator started."
};

enable_hardware_acceleration
sleep 1
launch_emulator
sleep 4
check_emulator_status
sleep 1
disable_animation
sleep 1
hidden_policy
sleep 1
access_emulator_with_adb
sleep 1
check_emulator_focus
sleep 1
