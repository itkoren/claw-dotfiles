#!/bin/bash

# Text Color Variables
readonly RED='\033[31m'   # Red
readonly GREEN='\033[32m' # Green
readonly CLEAR='\033[0m'  # Clear color and formatting

function println() {
    printf "\n${GREEN}%s${CLEAR}\n" "$*" 2>/dev/null
}

function print_err() {
    printf "\n${RED}%s${CLEAR}\n" "$*" >&2
}

function check_command() {
    command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        print_err "${command_name} is not installed."
        return 1
    fi

    return 0
}

function update_brew() {
  if ! check_command brew; then
      return
  fi
  
  println "Checking for homebrew packages..."
  brew update > /dev/null;
  new_packages=$(brew outdated --quiet)
  num_packages=$(echo $new_packages | wc -w)
  
  if [ $num_packages -gt 0 ]; then
    println "$num_packages New brew updates available:"
    
    for package in $new_packages; do
      println "		* $package";
    done
    
    println "Install brew updates? (y/n)"
    read answer
    if echo "$answer" | grep -iq "^y" ; then
      brew upgrade && println "Brew updates done!"
    fi
    
    println "Clean up old versions of brew packages? (y/n)"
    read answer
    if echo "$answer" | grep -iq "^y" ; then
      brew cleanup && println "Brew cleanup done!"
    fi
    
  else
    println "No brew updates available."
  fi

  println "Brew Diagnostics"
  brew doctor && brew missing
}

function update_app_store() {
  if ! check_command mas; then
      return
  fi

  # mac app store (requires https://github.com/mas-cli/mas)
  println "Checking for Mac App Store updates..."
  
  new_packages=$(mas outdated)
  echo $new_packages
  num_packages=$(echo $new_packages | wc -w)
  
  if [ $num_packages -gt 0 ]; then
  
    println "Install Mac App Store updates? (y/n)" 
    read answer
      if echo "$answer" | grep -iq "^y" ; then
      mas upgrade && println "Mac App Store updates done!"
    fi
  
  else
    println "No Mac App Store updates available."
  fi
}

function update_macos() {
  # macOS
  println "Checking macOS updates..."
  
  # Run softwareupdate -l and capture the output
  updates=$(softwareupdate -l 2>&1)

  if echo "$updates" | grep -q "No new software"; then
    println $updates
  else
    println $updates
    println "Install macOS updates, if any? (y/n)" 
    read answer
    if echo "$answer" | grep -iq "^y" ; then
      sudo softwareupdate -i -a && println "macOS updates done! You may need to reboot..."
    fi
  fi
}

function check_internet() {
  if ! check_command curl; then
      print_err "Error: curl is required but not installed. Please install curl."
      return 1
  fi

  # Check internet connection by pinging a reliable server
  TEST_URL="https://www.google.com"

  # Use curl to check the connection
  TEST_RESP=$(curl -Is --connect-timeout 5 --max-time 10 "${TEST_URL}" 2>/dev/null | head -n 1)

  # Check if response is empty
  if [ -z "${TEST_RESP}" ]; then
      print_err "No Internet Connection!!!"
      return 1
  fi

  # Check for "200" in the response
  if ! printf "%s" "${TEST_RESP}" | grep -q "200"; then
      print_err "Internet is not working!!!"
      return 1
  fi

  return 0
}

function update_all() {
  # Check if internet is available
  if ! check_internet; then
      exit 1
  fi

  update_brew
  update_app_store
  update_macos
}
