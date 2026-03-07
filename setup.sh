#!/usr/bin/env bash

set -Eeufo pipefail

trap 'echo "Error at line $LINENO: $BASH_COMMAND"' ERR

# Catch any command failure and run reset function
# trap 'reset_chezmoi_state' ERR

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

# shellcheck disable=SC2016
declare -r DOTFILES_LOGO='
                          /$$                                      /$$
                         | $$                                     | $$
     /$$$$$$$  /$$$$$$  /$$$$$$   /$$   /$$  /$$$$$$      /$$$$$$$| $$$$$$$
    /$$_____/ /$$__  $$|_  $$_/  | $$  | $$ /$$__  $$    /$$_____/| $$__  $$
   |  $$$$$$ | $$$$$$$$  | $$    | $$  | $$| $$  \ $$   |  $$$$$$ | $$  \ $$
    \____  $$| $$_____/  | $$ /$$| $$  | $$| $$  | $$    \____  $$| $$  | $$
    /$$$$$$$/|  $$$$$$$  |  $$$$/|  $$$$$$/| $$$$$$$//$$ /$$$$$$$/| $$  | $$
   |_______/  \_______/   \___/   \______/ | $$____/|__/|_______/ |__/  |__/
                                           | $$
                                           | $$
                                           |__/

             *** This is setup script for my dotfiles setup ***            
                     https://github.com/itkoren/claw-dotfiles
'

declare -r DOTFILES_USER_OR_REPO_URL="itkoren/claw-dotfiles"
declare -r BRANCH_NAME="${BRANCH_NAME:-main}"
declare -r DOTFILES_GITHUB_PAT="${DOTFILES_GITHUB_PAT:-}"
declare -r CI="${CI:-false}"

function is_ci() {
    [[ "${CI}" == "true" ]]
}

function is_tty() {
    # Check if the script is running in an interactive terminal
    if [ -t 1 ]; then
      if [ "${DOTFILES_DEBUG:-}" ]; then
        echo "Interactive terminal detected"
      fi
      return 0 # true
    else
      if [ "${DOTFILES_DEBUG:-}" ]; then
        echo "Non-interactive terminal detected"
      fi
      return 1 # false
    fi
}

function is_not_tty() {
    ! is_tty
}

# Improved check for CI or non-TTY
function is_ci_or_not_tty() {
    if is_ci; then
      if [ "${DOTFILES_DEBUG:-}" ]; then
        echo "CI: true"
      fi
      return 0  # CI environment, no input needed
    elif is_not_tty; then
      if [ "${DOTFILES_DEBUG:-}" ]; then
        echo "CI: false, Non-interactive terminal detected"
      fi
      return 0  # Non-interactive terminal
    else
      if [ "${DOTFILES_DEBUG:-}" ]; then
        echo "CI: false, Interactive terminal detected"
      fi
      return 1  # Interactive terminal
    fi
}

function at_exit() {
    AT_EXIT+="${AT_EXIT:+$'\n'}"
    AT_EXIT+="${*?}"
    # shellcheck disable=SC2064
    trap "${AT_EXIT}" EXIT
}

function get_os_type() {
    uname
}

function keepalive_sudo_linux() {
    # Might as well ask for password up-front, right?
    echo "Checking for \`sudo\` access which may request your password."
    sudo -v || { echo "sudo failed!"; exit 1; }

    # Keep-alive: update existing sudo time stamp if set, otherwise do nothing.
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}

function keepalive_sudo_macos() {
    # ref. https://github.com/reitermarkus/dotfiles/blob/master/.sh#L85-L116
    (
        builtin read -r -s -p "Password: " </dev/tty
        builtin echo "add-generic-password -U -s 'dotfiles' -a '${USER}' -w '${REPLY}'"
    ) | /usr/bin/security -i
    printf "\n"
    at_exit "
                echo -e '\033[0;31mRemoving password from Keychain …\033[0m'
                /usr/bin/security delete-generic-password -s 'dotfiles' -a '${USER}'
            "
    SUDO_ASKPASS="$(/usr/bin/mktemp)"
    at_exit "
                echo -e '\033[0;31mDeleting SUDO_ASKPASS script …\033[0m'
                /bin/rm -f '${SUDO_ASKPASS}'
            "
    {
        echo "#!/bin/sh"
        echo "/usr/bin/security find-generic-password -s 'dotfiles' -a '${USER}' -w"
    } >"${SUDO_ASKPASS}"

    /bin/chmod +x "${SUDO_ASKPASS}"
    export SUDO_ASKPASS

    if ! /usr/bin/sudo -A -kv 2>/dev/null; then
        echo -e '\033[0;31mIncorrect password.\033[0m' 1>&2
        exit 1
    fi
}

function keepalive_sudo() {

    local ostype
    ostype="$(get_os_type)"

    if [ "${ostype}" == "Darwin" ]; then
        keepalive_sudo_macos
    elif [ "${ostype}" == "Linux" ]; then
        keepalive_sudo_linux
    else
        echo "Invalid OS type: ${ostype}" >&2
        exit 1
    fi
}
function verify_dictation_shortcut() {
    echo "***************************************************************************"
    echo "***************************************************************************"
    echo "***************************************************************************"
    echo "**** Dictation Settings will be opened when you press the Enter button ****"
    echo "**** Please verify the Shortcut option is set to \"Press fn Twice\"    ****"
    echo "**** Press Enter button again once complete                            ****"
    echo "***************************************************************************"
    echo "***************************************************************************"
    echo "***************************************************************************"
    read
    open "x-apple.systempreferences:com.apple.preference.keyboard?Dictation"
    read -p "Press any key to continue." -n 1 -r
    echo
}
function initialize_os_macos() {
    function is_homebrew_exists() {
        command -v brew &>/dev/null
    }

    # Install the Xcode Command Line Tools.
    if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
        echo "===> Installing Xcode Command Line Tools"

        # Install Xcode Command Line Tools if not already installed
        if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
            echo "Installing Xcode Command Line Tools..."
            xcode-select --install
    
            # Wait for user to complete installation
            echo "******************************************************************************************"
            echo "******************************************************************************************"
            echo "******************************************************************************************"
            echo "**** Xcode Command Line Tools installation will start when you press the Enter button ****"
            echo "**** Please complete the Xcode Command Line Tools installation...                     ****"
            echo "**** Press Enter button again once the installation is complete.                      ****"
            echo "******************************************************************************************"
            echo "******************************************************************************************"
            echo "******************************************************************************************"
            read -p "Press any key to continue." -n 1 -r
            echo
    
            # Verify installation
            until [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; do
                echo "Waiting for Command Line Tools to be installed..."
                sleep 5
            done
        fi
    fi

    # Accept T&Cs if needed
    # Check if full Xcode is installed
    if [ -d "/Applications/Xcode.app" ]; then
        # Set the active developer directory to Xcode if not already set
        if ! xcode-select -p | grep -q '/Applications/Xcode.app'; then
            echo "Setting active developer directory to Xcode..."
            sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
        fi

        # Accept the Xcode license if not already accepted
        if sudo xcodebuild -license check &>/dev/null; then
            echo "Xcode license already accepted."
        else
            echo "Xcode license has not been accepted."
            echo "Accepting the Xcode license..."
            sudo xcodebuild -license accept
            echo "Xcode license accepted."
        fi
    else
        # If only Command Line Tools are installed, handle accepting the license
        if [ -d "/Library/Developer/CommandLineTools" ]; then
            # Set the active developer directory to Command Line Tools if not already set
            if ! xcode-select -p | grep -q '/Library/Developer/CommandLineTools'; then
                echo "Setting active developer directory to Command Line Tools..."
                sudo xcode-select --switch /Library/Developer/CommandLineTools
            fi
        fi
    fi

    # Verify dictation shortcut 
    verify_dictation_shortcut

    # Instal Homebrew if needed.
    if ! is_homebrew_exists; then
        echo '🍺  Installing Homebrew'
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Homebrew is already installed"
    fi

    # Setup Homebrew envvars.
    if [[ $(arch) == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ $(arch) == "i386" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        echo "Invalid CPU arch: $(arch)" >&2
        exit 1
    fi
}

function initialize_os_linux() {
    if which nix; then
        echo 'Nix is already installed'
    else
        # sh <(curl -L https://nixos.org/nix/install) --daemon
        sh <(curl -L https://nixos.org/nix/install) --no-daemon
    fi
}

function initialize_os_env() {
    local ostype
    ostype="$(get_os_type)"

    if [ "${ostype}" == "Darwin" ]; then
        initialize_os_macos
    elif [ "${ostype}" == "Linux" ]; then
        initialize_os_linux
    else
        echo "Invalid OS type: ${ostype}" >&2
        exit 1
    fi
}

# Function to reset chezmoi state before exiting
function reset_chezmoi_state() {
  echo "An error occurred!"
  yn="y" # If non-interactive, assume they want to skip
  if ! is_ci_or_not_tty; then
    read -p "Do you wish to reset chezmoi state? (y/n): " yn
  fi
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    echo "Resetting chezmoi state..."
    chezmoi state reset
    rm -r * ~/.config/chezmoi/
    rm -rf ~/.config/chezmoi
    rm -r * ~/.local/share/chezmoi/
    rm -rf ~/.local/share/chezmoi
  else
    echo "Leaving chezmoi state..."  
  fi
}

function run_chezmoi() {
    function is_chezmoi_exists() {
        command -v chezmoi &>/dev/null
    }

    local chezmoi_cmd
    local no_tty_option
    local remove_chezmoi
    local ostype
    
    ostype="$(get_os_type)"
    
    echo "going to check chezmoi requirements"
    # Check if chezmoi is installed
    if ! is_chezmoi_exists; then
        echo "chezmoi is not installed. Let's proceed with installation."
        # install chezmoi via brew or download the chezmoi binary from the URL
        if ! is_ci_or_not_tty; then
            read -p "Do you wish to keep chezmoi after installation? (y/n): " yn
        else
            yn="y" # If non-interactive, assume they want to keep
        fi
        if [[ "$yn" =~ ^[Nn]$ ]]; then
            # Download chezmoi binary
            echo '👊  Temporary downloading chezmoi binary'
            sh -c "$(curl -fsLS get.chezmoi.io)"
            chezmoi_cmd="./bin/chezmoi"
            remove_chezmoi=1
            echo "chezmoi binary downloaded to $chezmoi_cmd"
        elif [ "${ostype}" == "Darwin" ]; then
            # Install chezmoi using brew
            echo '👊  Installing chezmoi'
            brew install chezmoi
            chezmoi_cmd=$(which chezmoi)
            echo "chezmoi installed via brew, path: $chezmoi_cmd"
        elif [ "${ostype}" == "Linux" ]; then
            nix-env -i chezmoi
            chezmoi_cmd=$(which chezmoi)
            echo "chezmoi installed via nix, path: $chezmoi_cmd"
        else
            echo "Invalid OS type: ${ostype}" >&2
            exit 1
        fi
    else
        echo "chezmoi is already installed"
        chezmoi_cmd=$(which chezmoi)
        echo "chezmoi found at: $chezmoi_cmd"
    fi    

    echo "Checking chezmoi_cmd: $chezmoi_cmd"
    if [ -z "$chezmoi_cmd" ]; then
        echo "Error: chezmoi_cmd is not set properly." >&2
        exit 1
    fi
    
    if is_ci_or_not_tty; then
        no_tty_option="--no-tty" # /dev/tty is not available (especially in the CI)
    else
        no_tty_option="" # /dev/tty is available OR not in the CI
    fi
    if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
      echo "🚸  chezmoi already initialized"
    else
      echo "🚀  Initialize dotfiles with:"
    fi

    # run `chezmoi init` to setup the source directory,
    # generate the config file, and optionally update the destination directory
    # to match the target state.
    echo "Command being executed: ${chezmoi_cmd} init -v ${DOTFILES_USER_OR_REPO_URL} --force --branch ${BRANCH_NAME} --use-builtin-git true ${no_tty_option}"
    if [ "${DOTFILES_DEBUG:-}" ]; then
        if ! "${chezmoi_cmd}" init -v "${DOTFILES_USER_OR_REPO_URL}" \
                --force \
                --branch "${BRANCH_NAME}" \
                --use-builtin-git true \
                --debug \
                --verbose \
                ${no_tty_option}; then
          reset_chezmoi_state
          exit 1  # Exit the script with a failure status
        fi
    else
        if ! "${chezmoi_cmd}" init -v "${DOTFILES_USER_OR_REPO_URL}" \
            --force \
            --branch "${BRANCH_NAME}" \
            --use-builtin-git true \
            ${no_tty_option}; then
          reset_chezmoi_state
          exit 1  # Exit the script with a failure status
        fi
    fi

    # the `age` command requires a tty, but there is no tty in the github actions.
    # Therefore, it is currnetly difficult to decrypt the files encrypted with `age` in this workflow.
    # I decided to temporarily remove the encrypted target files from chezmoi's control.
    if is_ci_or_not_tty; then
        find "$(${chezmoi_cmd} source-path)" -type f -name "encrypted_*" -exec rm -fv {} +
    fi

    # Add to PATH for installing the necessary binary files under `$HOME/.local/bin`.
    export PATH="${PATH}:${HOME}/.local/bin"
    
    if [[ -n "${DOTFILES_GITHUB_PAT}" ]]; then
        export DOTFILES_GITHUB_PAT
    fi

    # run `chezmoi apply` to ensure that target... are in the target state,
    # updating them if necessary.
    if ! "${chezmoi_cmd}" apply ${no_tty_option}; then
      reset_chezmoi_state
      exit 1  # Exit the script with a failure status
    fi

    if [ -n "$remove_chezmoi" ]; then
        # purge the binary of the chezmoi cmd
        rm -fv "${chezmoi_cmd}"
    fi
}

function initialize_dotfiles() {
    if ! is_ci_or_not_tty; then
        # - /dev/tty of the github workflow is not available.
        # - We can use password-less sudo in the github workflow.
        # Therefore, skip the sudo keep alive function.
        keepalive_sudo
    fi
    run_chezmoi
}

function get_system_from_chezmoi() {
    local system
    system=$(chezmoi data | jq -r '.system')
    echo "${system}"
}

function restart_shell_system() {
    local system
    system=$(get_system_from_chezmoi)

    # exec shell as login shell (to reload the .zprofile or .profile)
    if [ "${system}" == "client" ]; then
        /bin/zsh --login

    elif [ "${system}" == "server" ]; then
        /bin/bash --login

    else
        echo "Invalid system: ${system}; expected \`client\` or \`server\`" >&2
        exit 1
    fi
}

function restart_shell() {

    # Restart shell if specified "bash -c $(curl -L {URL})"
    # not restart:
    #   curl -L {URL} | bash
    if [ -p /dev/stdin ]; then
        echo "Now continue with Rebooting your shell"
    else
        echo "Restarting your shell..."
        restart_shell_system
    fi
}

function main() {

    echo ""
    echo "🤚  This script will setup .dotfiles for you."

    if ! is_ci_or_not_tty; then
        echo "Interactive terminal detected, waiting for input."
        
        # Ask the user if they want to continue, but only in interactive environments
        if is_tty; then
            # Prompt user for input
            read -p "Do you wish to continue? (y/n): " response
        
            # Convert response to lowercase for case-insensitive comparison
            response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
            echo "User input: $response"  # Debugging output
            
            # Handle response validation
            if [[ "$response" == "y" ]]; then
                echo "Continuing with dotfiles setup..."
            else
                echo "Exiting the script."
                exit 0
            fi
        else
            echo "Skipping prompt, as this is a non-interactive terminal."
        fi
    else
        echo "Skipping prompt in non-interactive or CI environment."
    fi
    
    echo "$DOTFILES_LOGO"

    echo "Initializing OS environment..."
    initialize_os_env
    echo "Setting up dotfiles..."
    initialize_dotfiles

    # restart_shell # Disabled because the at_exit function does not work properly.
}

main
