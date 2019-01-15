#!/bin/bash -e
#
# Copyright 2019-present The Material Foundation Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# A script containing various simulator cleanup functions for testing.

# Returns a space-separated list of simulator IDs matching the provided name
# prefix and device state. If device state is empty, all matching simulator IDs
# will be returned.
# Name prefix is the first parameter and device state is the second parameter.
# Example: get_simulator_ids "iPhone" "Shutdown" will return space-separated
# list of IDs for all simulators that begin with "iPhone" and are in shutdown
# state.
function get_simulator_ids() {
  SED_CMD="/${1}/s/.* (\\(.*\\)) (\\(${2}\\).*)/\\1/p"
  # sort will dedup and xargs will convert output to space-separated values.
  xcrun simctl list devices | sed -n "${SED_CMD}" | sort -u | xargs
}

# Performs the specified cleanup action on simulators matching the provided
# name prefix and device state.
# Simulator name prefix is the first parameter.
# Simulator device state is the second parameter and can be empty, in which case
# all simulators with name prefix are matched.
# Action is the third parameter and should be either "shutdown" or "delete"
# Depending on the provided action, the matched simulators are either shut down
# or deleted.
function perform_cleanup_action() {
  if [[ -z "${1}" ]]; then
    echo "First parameter is unset or empty."
    exit 1
  fi

  SIM_IDS=$(get_simulator_ids "${1}" "${2}")
  if [[ ! -z "${SIM_IDS}" ]]; then
    read -ra SIM_IDS_ARRAY <<< "${SIM_IDS}"
    if [[ "${3}" = "shutdown" ]]; then
      echo "Simulator IDs to shutdown: ${SIM_IDS}"
      xcrun simctl shutdown "${SIM_IDS_ARRAY[@]}"
    elif [[ "${3}" = "delete" ]]; then
      echo "Simulator IDs to delete: ${SIM_IDS}"
      xcrun simctl delete "${SIM_IDS_ARRAY[@]}"
    else
     echo "Invalid action: ${3}. Must be either shutdown or delete."
     exit 1
    fi
  fi
}

# Synchronously removes simulators left behind by other test actions.
function perform_pre_test_cleanup() {
  if [[ -z "$1" ]]; then
    echo "A simulator prefix is required."
    exit 1
  fi

  killall Simulator >/dev/null 2>&1 || echo "No Simulator.app running."
  xcrun simctl shutdown booted

  CORE_SIM_PROCESS_NAME="com.apple.CoreSimulator.CoreSimulatorService"
  launchctl kickstart -k "user/$(id -u)/${CORE_SIM_PROCESS_NAME}"
  killall -9 SimStreamProcessorService >/dev/null 2>&1 || true
  killall -9 SimAudioProcessorService >/dev/null 2>&1 || true

  # Delete previously created simulators that are already shut down.
  # Delete operation can sometimes fail so guard against it.
  perform_cleanup_action "$1" "Shutdown" "delete" || true
}

