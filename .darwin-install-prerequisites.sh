#!/bin/bash
set -ex

function force_install_prerequisite() {
    local prerequisite="$1"
    local is_cask="$2"
    if [ -n "$is_cask" ]; then
        if ! brew install --cask "$prerequisite" > /dev/null 2>&1; then
            read -p "$prerequisite is already installed, would you like to re-install it? (y/n): " yn
            if [[ "$yn" =~ ^[Yy]$ ]]; then
                brew install --cask --force "$prerequisite"
            fi
        fi
    else
        if ! brew install "$prerequisite" > /dev/null 2>&1; then
            read -p "$prerequisite is already installed, would you like to re-install it? (y/n): " yn
            if [[ "$yn" =~ ^[Yy]$ ]]; then
                brew install --force "$prerequisite"
            fi
        fi
    fi
}

function install_prerequisite() {
    local prerequisite="$1"
    local is_tap="$2"
    local is_cask="$3"

    if [ -n "$is_tap" ]; then
        brew tap "$prerequisite"
    elif [ -n "$is_cask" ]; then
        if ! brew list --cask "$prerequisite" > /dev/null 2>&1; then
            force_install_prerequisite "$prerequisite" 1
        else
            read -p "$prerequisite is already installed, would you like to re-install it? (y/n): " yn
            if [[ "$yn" =~ ^[Yy]$ ]]; then
                brew install --cask --force "$prerequisite"
            fi
        fi
    else
        if ! brew list "$prerequisite" > /dev/null 2>&1; then
            force_install_prerequisite "$prerequisite" ""
        else
            read -p "$prerequisite is already installed, would you like to re-install it? (y/n): " yn
            if [[ "$yn" =~ ^[Yy]$ ]]; then
                brew install --force "$prerequisite"
            fi
        fi
    fi
}

case "$(uname -s)" in
Darwin)
    install_prerequisite "git" 1 ""
    install_prerequisite "1password/tap" 1 ""
    install_prerequisite "1password-cli" "" ""
    install_prerequisite "git-delta" "" ""
    ;;
*)
    echo "unsupported OS"
    exit 1
    ;;
esac

# Post-installation instructions
echo "*************************************"
echo "*************************************"
echo "*************************************"
echo "**** Press the Enter button      ****"
echo "*************************************"
echo "*************************************"
echo "*************************************"
read -p "Press any key to continue." -n 1 -r
echo
