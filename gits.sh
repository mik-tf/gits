#!/bin/bash

# ANSI color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to perform git pull operations
pull() {
    local branch=${1:-development}
    git checkout "$branch" && git stash && git fetch && git pull && git status
}

# Function to perform git push operations
push() {
    git add .
    echo "Enter commit message:"
    read commit_message
    git commit -m "$commit_message"
    git push
}

# Function to perform git commit operation
commit() {
    echo "Enter commit message:"
    read commit_message
    git commit -m "$commit_message"
}

# Function to initialize a new Git repository and push to GitHub
init() {
    echo -e "${YELLOW}Initializing new Git repository and pushing to GitHub...${NC}"
    
    echo -e "Enter your GitHub username:"
    read github_username
    echo -e "Enter the repository name:"
    read repo_name

    echo -e "${YELLOW}Make sure to create a repository on GitHub with the proper username (${github_username}) and repository (${repo_name})${NC}"
    echo -e "Press Enter when you're ready to continue..."
    read

    git init

    initial_branch="main"
    echo -e "${YELLOW}Setting initial branch as '${initial_branch}'. Press ENTER to continue or type 'replace' to change the branch name:${NC}"
    read branch_choice

    if [[ $branch_choice == "replace" ]]; then
        echo -e "Enter the new branch name:"
        read new_branch_name
        initial_branch=$new_branch_name
    fi

    git checkout -b $initial_branch
    git add .

    echo "Enter initial commit message:"
    read commit_message
    git commit -m "$commit_message"

    git remote add origin "https://github.com/$github_username/$repo_name.git"
    git push -u origin $initial_branch

    echo -e "${GREEN}Repository initialized and pushed to GitHub successfully.${NC}"
    echo -e "Branch: ${BLUE}$initial_branch${NC}"
}

# Function to create a new branch
new() {
    if [ -z "$1" ]; then
        echo -e "Enter the name of the new branch:"
        read branch_name
    else
        branch_name="$1"
    fi
    git checkout -b "$branch_name"
    echo -e "${GREEN}New branch '${branch_name}' created and checked out.${NC}"
}

# Function to install the script
install() {
    echo -e "${YELLOW}Installing GitS...${NC}"
    if sudo -v; then
        sudo cp "$0" /usr/local/bin/gits
        sudo chown root:root /usr/local/bin/gits
        sudo chmod 755 /usr/local/bin/gits

        echo -e "${GREEN}GitS has been installed successfully.${NC}"
        echo -e "You can now use ${YELLOW}gits${NC} command from anywhere."
        echo -e "Use ${BLUE}gits help${NC} to see the commands."
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Installation aborted.${NC}"
        exit 1
    fi
}

# Function to uninstall the script
uninstall() {
    echo -e "${YELLOW}Uninstalling GitS...${NC}"
    if sudo -v; then
        sudo rm -f /usr/local/bin/gits
        echo -e "${GREEN}GitS has been uninstalled successfully.${NC}"
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Uninstallation aborted.${NC}"
        exit 1
    fi
}

help() {
    echo -e "${BLUE}GitS - Git Speed${NC}"
    echo -e "${YELLOW}Description:${NC} GitS is a tool for quickly combining git commands to speed up your workflow."
    echo -e "${YELLOW}Usage:${NC} gits <command>"
    echo
    echo -e "${GREEN}Available commands:${NC}"
    echo -e "  ${YELLOW}pull [branch]${NC} Quickly update your local repository"
    echo -e "             ${BLUE}Actions:${NC} checkout branch, stash changes, fetch, pull, show status"
    echo -e "             ${BLUE}Note:${NC} If no branch is specified, it defaults to 'development'"
    echo -e "             ${BLUE}Example:${NC} gits pull"
    echo -e "             ${BLUE}Example:${NC} gits pull main"
    echo
    echo -e "  ${YELLOW}push${NC}          Rapidly stage, commit, and push changes"
    echo -e "             ${BLUE}Actions:${NC} add all changes, prompt for commit message, commit, push"
    echo -e "             ${BLUE}Example:${NC} gits push"
    echo
    echo -e "  ${YELLOW}commit${NC}        Commit changes with a message"
    echo -e "             ${BLUE}Actions:${NC} prompt for commit message, commit"
    echo -e "             ${BLUE}Example:${NC} gits commit"
    echo
    echo -e "  ${YELLOW}init${NC}          Initialize a new Git repository and push to GitHub"
    echo -e "             ${BLUE}Actions:${NC} init repo, create initial branch, add files, commit, push to GitHub"
    echo -e "             ${BLUE}Example:${NC} gits init"
    echo
    echo -e "  ${YELLOW}new [name]${NC}    Create a new branch and switch to it"
    echo -e "             ${BLUE}Actions:${NC} create new branch, switch to it"
    echo -e "             ${BLUE}Note:${NC} If no name is provided, you'll be prompted to enter one"
    echo -e "             ${BLUE}Example:${NC} gits new"
    echo -e "             ${BLUE}Example:${NC} gits new feature-branch"
    echo
    echo -e "  ${YELLOW}install${NC}       Install GitS to /usr/local/bin (requires sudo)"
    echo -e "             ${BLUE}Example:${NC} gits install"
    echo
    echo -e "  ${YELLOW}uninstall${NC}     Remove GitS from /usr/local/bin (requires sudo)"
    echo -e "             ${BLUE}Example:${NC} gits uninstall"
    echo
    echo -e "  ${YELLOW}help${NC}          Display this help message"
    echo -e "             ${BLUE}Example:${NC} gits help"
    echo
    echo -e "${GREEN}Examples:${NC}"
    echo -e "  ${BLUE}Pull changes:${NC}"
    echo -e "    gits pull"
    echo
    echo -e "  ${BLUE}Push changes:${NC}"
    echo -e "    gits push"
    echo -e "    ${YELLOW}Enter commit message:${NC} Update README.md"
    echo
    echo -e "${YELLOW}Note:${NC} Ensure you're in your git repository directory when running git-related commands."
}

# Main execution logic
main() {
    if [ $# -eq 0 ]; then
        help
        exit 1
    fi

    case "$1" in
        pull)
            shift
            pull "$@"
            ;;
        push)
            push
            ;;
        commit)
            commit
            ;;
        init)
            init
            ;;
        new)
            shift
            new "$@"
            ;;
        install)
            install
            ;;
        uninstall)
            uninstall
            ;;
        help)
            help
            ;;
        *)
            echo -e "${YELLOW}Unknown command:${NC} $1"
            echo "Run 'gits help' for usage information."
            exit 1
            ;;
    esac
}

# Run the main function
main "$@"