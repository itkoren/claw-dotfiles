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

function initialize_os_env() {
    function is_homebrew_exists() {
        command -v brew &>/dev/null
    }

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
    run_chezmoi
}

function get_system_from_chezmoi() {
    local system
    system=$(chezmoi data | jq -r '.system')
    echo "${system}"
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
    echo "Restarting shell..."
    exec $SHELL
}

main
