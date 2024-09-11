#!/bin/bash

# generated with Cursor and claude-3.5-sonnet

# This script checks for version updates of tools defined in the Dockerfile.
# It expects ARG lines with VERSION in their name, and corresponding GitHub URLs.
# The script extracts current versions from the Dockerfile, fetches the latest
# versions from GitHub, and compares them. It then displays both versions,
# highlighting any differences. Use --update to update the Dockerfile.
# NOTE: only tested on macOS versions of grep, sed, curl, and awk.


# Text formatting
BOLD='\033[1m'
RESET='\033[0m'

# Optionally support GitHub API token for rate limiting via shell variable
GITHUB_API_KEY="${GITHUB_API_KEY:-}"

# Function to extract version from GitHub API
get_latest_version() {
    local repo="$1"
    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    local curl_opts=(-s)
    
    # Add authorization header if API key is provided
    if [ -n "$GITHUB_API_KEY" ]; then
        curl_opts+=(-H "Authorization: token $GITHUB_API_KEY")
    fi
    
    # Fetch the latest version and extract the tag name
    local version=$(curl "${curl_opts[@]}" "$api_url" | jq -r .tag_name)
    
    # Strip non-numerical characters, keeping only numbers and dots
    version=$(echo "$version" | sed 's/[^0-9.]//g')
    echo "$version"
}

# Detect if running on macOS
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Function to update Dockerfile
update_dockerfile() {
    local package="$1"
    local new_version="$2"
    if is_macos; then
        # macOS version of sed requires an empty string after -i
        sed -i '' "s/ARG ${package}_VERSION=.*/ARG ${package}_VERSION=${new_version}/" Dockerfile
    else
        # Linux version of sed
        sed -i "s/ARG ${package}_VERSION=.*/ARG ${package}_VERSION=${new_version}/" Dockerfile
    fi
}

# Check for CLI option
update_mode=false
if [ "$1" == "--update" ]; then
    update_mode=true
fi

# Read the Dockerfile
dockerfile_content=$(cat Dockerfile)

# Find all ARGs with VERSION in their name
while IFS= read -r line; do
    if [[ $line =~ ARG.*VERSION ]]; then
        # Extract the package name and current version
        arg_name=$(echo "$line" | awk -F'=' '{print $1}' | awk '{print $2}')
        current_version=$(echo "$line" | awk -F'=' '{print $2}')

        # Find the corresponding GitHub URL
        github_url=$(echo "$dockerfile_content" | grep -B 5 "$line" | grep 'https://github.com' | tail -n1 | awk '{print $2}')
        
        if [[ -n $github_url ]]; then
            # Extract owner and repo from GitHub URL
            repo=$(echo "$github_url" | sed -E 's|https://github.com/||' | sed -E 's|/releases/latest||')
            
            # Get the latest version from GitHub
            latest_version=$(get_latest_version "$repo")

            # Display version information
            echo "Package: ${arg_name%_VERSION}"
            echo "  Dockerfile version: $current_version"
            if [ "$current_version" != "$latest_version" ]; then
                echo -e "  Latest version:     ${BOLD}${latest_version}${RESET}"
                if [ "$update_mode" = true ]; then
                    # Prompt user for update
                    echo -n "Do you want to update this package to the latest version? (y/N) "
                    read -r response < /dev/tty
                    if [[ "$response" =~ ^[Yy]$ ]]; then
                        update_dockerfile "${arg_name%_VERSION}" "$latest_version"
                        echo "Updated ${arg_name%_VERSION} to version $latest_version in Dockerfile"
                    fi
                fi
            else
                echo "  Latest version:     $latest_version"
            fi
            echo
        fi
    fi
done < <(echo "$dockerfile_content")

if [ "$update_mode" = false ]; then
    echo "Run with --update option to enable updating the Dockerfile."
fi
