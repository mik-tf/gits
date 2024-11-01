#!/bin/bash

# ANSI color codes
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[38;5;208m'
NC='\033[0m' # No Color

# Function to delete a branch
delete() {
    # If branch name is provided as argument, use it; otherwise ask
    if [ -z "$1" ]; then
        # Show all branches first
        echo -e "${BLUE}Current branches:${NC}"
        git branch -a
        
        echo -e "\n${GREEN}Enter branch name to delete:${NC}"
        read branch_name
    else
        branch_name="$1"
    fi

    # Get the default branch (usually main or master)
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    
    # If we couldn't get the default branch, ask the user
    if [ -z "$default_branch" ]; then
        echo -e "${GREEN}Enter the name of your main branch (main/master):${NC}"
        read default_branch
        default_branch=${default_branch:-main}
    fi
    
    # Check if the branch exists
    if ! git show-ref --verify --quiet refs/heads/"$branch_name"; then
        echo -e "${RED}Error: Branch '$branch_name' does not exist locally.${NC}"
        return 1
    fi

    # Don't allow deletion of the default branch
    if [ "$branch_name" = "$default_branch" ]; then
        echo -e "${RED}Error: Cannot delete the default branch ($default_branch).${NC}"
        return 1
    fi
    
    # Switch to the default branch first if needed
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" = "$branch_name" ]; then
        echo -e "${PURPLE}Switching to $default_branch before deletion...${NC}"
        if ! git checkout "$default_branch"; then
            echo -e "${RED}Failed to switch to $default_branch branch. Branch deletion aborted.${NC}"
            return 1
        fi
    fi

    # Try to delete the branch
    if git branch -d "$branch_name"; then
        echo -e "${PURPLE}Branch deleted locally.${NC}"
        
        echo -e "${GREEN}Push branch deletion to remote? (y/n)${NC}"
        read push_delete

        if [[ $push_delete == "y" ]]; then
            if git push origin :"$branch_name"; then
                echo -e "${PURPLE}Branch deletion pushed to remote.${NC}"
            else
                echo -e "${RED}Failed to delete remote branch. It might not exist or you may not have permission.${NC}"
            fi
        fi
    else
        echo -e "${RED}Failed to delete branch locally.${NC}"
        echo -e "${ORANGE}If the branch has unmerged changes, use -D instead of -d to force deletion.${NC}"
        echo -e "${GREEN}Would you like to force delete the branch? (y/n)${NC}"
        read force_delete
        
        if [[ $force_delete == "y" ]]; then
            if git branch -D "$branch_name"; then
                echo -e "${PURPLE}Branch force deleted locally.${NC}"
                
                echo -e "${GREEN}Push branch deletion to remote? (y/n)${NC}"
                read push_delete

                if [[ $push_delete == "y" ]]; then
                    if git push origin :"$branch_name"; then
                        echo -e "${PURPLE}Branch deletion pushed to remote.${NC}"
                    else
                        echo -e "${RED}Failed to delete remote branch. It might not exist or you may not have permission.${NC}"
                    fi
                fi
            else
                echo -e "${RED}Failed to force delete the branch.${NC}"
            fi
        fi
    fi
}

# Function to handle pull request operations
pr() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Please specify an action (create/close/merge)${NC}"
        echo -e "Usage: gits pr <create|close|merge>"
        return 1
    fi

    # Ask user which platform to use
    echo -e "${GREEN}Which platform would you like to use?${NC}"
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    case "$1" in
        create)
            pr_create "$platform_choice"
            ;;
        close)
            pr_close "$platform_choice"
            ;;
        merge)
            pr_merge "$platform_choice"
            ;;
        *)
            echo -e "${RED}Invalid action. Use create, close, or merge${NC}"
            return 1
            ;;
    esac
}

# Function to create a pull request
pr_create() {
    local platform_choice=$1

    if [ "$platform_choice" = "1" ]; then
        # Show current PRs
        echo -e "${BLUE}Current Pull Requests:${NC}"
        tea pr

        # Get repository details
        echo -e "\n${GREEN}Enter repository (organization/repository):${NC}"
        read repo

        echo -e "${GREEN}Enter Pull Request title:${NC}"
        read title

        echo -e "${GREEN}Enter base branch (default: development):${NC}"
        read base
        base=${base:-development}

        echo -e "${GREEN}Enter head branch:${NC}"
        read head

        echo -e "\n${PURPLE}Creating Pull Request...${NC}"
        tea pull create --repo "$repo" --title "$title" --base "$base" --head "$head"
    else
        # GitHub PR creation
        echo -e "${BLUE}Current Pull Requests:${NC}"
        gh pr list

        echo -e "${GREEN}Enter Pull Request title:${NC}"
        read title

        echo -e "${GREEN}Enter base branch (default: main):${NC}"
        read base
        base=${base:-main}

        echo -e "${GREEN}Enter head branch:${NC}"
        read head

        echo -e "${GREEN}Enter PR description:${NC}"
        read description

        echo -e "\n${PURPLE}Creating Pull Request...${NC}"
        gh pr create --base "$base" --head "$head" --title "$title" --body "$description"
    fi
}

# Function to close a pull request
pr_close() {
    local platform_choice=$1

    if [ "$platform_choice" = "1" ]; then
        # Show current PRs
        echo -e "${BLUE}Current Pull Requests:${NC}"
        tea pr

        echo -e "\n${GREEN}Enter repository (organization/repository):${NC}"
        read repo

        echo -e "${GREEN}Enter PR number to close:${NC}"
        read pr_number

        echo -e "\n${PURPLE}Closing Pull Request #$pr_number...${NC}"
        tea pr close "$pr_number" --repo "$repo"
    else
        # Show current PRs
        echo -e "${BLUE}Current Pull Requests:${NC}"
        gh pr list

        echo -e "${GREEN}Enter PR number to close:${NC}"
        read pr_number

        echo -e "\n${PURPLE}Closing Pull Request #$pr_number...${NC}"
        gh pr close "$pr_number"
    fi
}

# Function to merge a pull request
pr_merge() {
    local platform_choice=$1

    if [ "$platform_choice" = "1" ]; then
        # Show current PRs
        echo -e "${BLUE}Current Pull Requests:${NC}"
        tea pr

        echo -e "\n${GREEN}Enter repository (organization/repository):${NC}"
        read repo

        echo -e "${GREEN}Enter PR number to merge:${NC}"
        read pr_number

        echo -e "${GREEN}Enter merge commit title:${NC}"
        read merge_title

        echo -e "${GREEN}Enter merge commit message:${NC}"
        read merge_message

        echo -e "\n${PURPLE}Merging Pull Request #$pr_number...${NC}"
        tea pr merge --repo "$repo" --title "$merge_title" --message "$merge_message" "$pr_number"

        # Branch deletion option only for Gitea
        echo -e "\n${GREEN}Would you like to delete the branch locally? (y/n)${NC}"
        read delete_branch

        if [[ $delete_branch == "y" ]]; then
            echo -e "${GREEN}Enter branch name to delete:${NC}"
            read branch_name
            
            # Get the default branch (usually main or master)
            default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
            
            # If we couldn't get the default branch, ask the user
            if [ -z "$default_branch" ]; then
                echo -e "${GREEN}Enter the name of your main branch (main/master):${NC}"
                read default_branch
                default_branch=${default_branch:-main}
            fi
            
            # Switch to the default branch first
            if git checkout "$default_branch"; then
                if git branch -d "$branch_name"; then
                    echo -e "${PURPLE}Branch deleted locally.${NC}"
                    
                    echo -e "${GREEN}Push branch deletion to remote? (y/n)${NC}"
                    read push_delete

                    if [[ $push_delete == "y" ]]; then
                        git push origin :"$branch_name"
                        echo -e "${PURPLE}Branch deletion pushed to remote.${NC}"
                    fi
                else
                    echo -e "${RED}Failed to delete branch locally.${NC}"
                fi
            else
                echo -e "${RED}Failed to switch to $default_branch branch. Branch deletion aborted.${NC}"
            fi
        fi
    else
        # Show current PRs
        echo -e "${BLUE}Current Pull Requests:${NC}"
        gh pr list

        echo -e "${GREEN}Enter PR number to merge:${NC}"
        read pr_number

        echo -e "\n${PURPLE}Merging Pull Request #$pr_number...${NC}"
        gh pr merge "$pr_number"
        echo -e "${PURPLE}Note: GitHub automatically handles branch deletion during PR merge.${NC}"
    fi
}

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

    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if git config --get branch."$current_branch".merge &>/dev/null; then
        echo -e "${GREEN}Pushing changes to existing upstream branch${NC}"
        git push
    else
        echo -e "${ORANGE}No upstream branch set. Setting upstream to origin/$current_branch${NC}"
        git push --set-upstream origin "$current_branch"
    fi
}

# Function to perform git commit operation
commit() {
    echo "Enter commit message:"
    read commit_message
    git commit -m "$commit_message"
}

# Function to initialize a new Git repository and push to GitHub
init() {
    echo -e "${GREEN}Initializing new Git repository and pushing to GitHub...${NC}"
    
    echo -e "Enter your GitHub username:"
    read github_username
    echo -e "Enter the repository name:"
    read repo_name

    echo -e "${GREEN}Make sure to create a repository on GitHub with the proper username (${github_username}) and repository (${repo_name})${NC}"
    echo -e "Press Enter when you're ready to continue..."
    read

    git init

    initial_branch="main"
    echo -e "${GREEN}Setting initial branch as '${initial_branch}'. Press ENTER to continue or type 'replace' to change the branch name:${NC}"
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

    echo -e "${PURPLE}Repository initialized and pushed to GitHub successfully.${NC}"
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
    echo -e "${PURPLE}New branch '${branch_name}' created and checked out.${NC}"
}

# Function to revert a specified number of commits
revert() {
    if [ -z "$1" ] || ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Please provide a valid number of commits to revert.${NC}"
        echo -e "Usage: gits revert <number>"
        return 1
    fi

    num_commits=$1
    commit_to_revert="HEAD~$((num_commits-1))"

    echo -e "${GREEN}Reverting to $num_commits commit(s) ago...${NC}"
    
    if git revert --no-commit "$commit_to_revert"; then
        echo -e "${PURPLE}Changes have been staged. Review the changes and commit when ready.${NC}"
        echo -e "Use ${BLUE}git status${NC} to see the changes."
        echo -e "Use ${BLUE}git commit -m 'Revert message'${NC} to commit the revert."
    else
        echo -e "${RED}Error occurred while reverting. Please resolve conflicts if any.${NC}"
    fi
}

# Function to cancel the last revert
unrevert() {
    echo -e "${GREEN}Cancelling the last revert...${NC}"
    if git reset --hard HEAD; then
        echo -e "${PURPLE}Last revert has been cancelled successfully.${NC}"
    else
        echo -e "${RED}Error occurred while cancelling the revert. Please check your Git status.${NC}"
    fi
}

# Function to install the script
install() {
    echo -e "${GREEN}Installing GitS...${NC}"
    if sudo -v; then
        sudo cp "$0" /usr/local/bin/gits
        sudo chown root:root /usr/local/bin/gits
        sudo chmod 755 /usr/local/bin/gits

        echo -e "${PURPLE}GitS has been installed successfully.${NC}"
        echo -e "You can now use ${GREEN}gits${NC} command from anywhere."
        echo -e "Use ${BLUE}gits help${NC} to see the commands."
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Installation aborted.${NC}"
        exit 1
    fi
}

# Function to uninstall the script
uninstall() {
    echo -e "${GREEN}Uninstalling GitS...${NC}"
    if sudo -v; then
        sudo rm -f /usr/local/bin/gits
        echo -e "${PURPLE}GitS has been uninstalled successfully.${NC}"
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Uninstallation aborted.${NC}"
        exit 1
    fi
}

# Function to clone a GitHub repository
clone() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Please provide a Git repository URL or just the org/repo if it's on GitHub. ${NC}"
        echo -e "Usage: gits clone <https://github.com/org/repo> or <org/repo>"
        return 1
    fi

    local repo="$1"
    if [[ $repo != http* ]]; then
        repo="https://github.com/$repo"
    fi

    echo -e "${GREEN}Cloning repository: $repo${NC}"
    if git clone "$repo"; then
        local repo_name=$(basename "$repo" .git)
        cd "$repo_name"
        echo -e "${PURPLE}Repository cloned successfully. Switched to directory: $(pwd)${NC}"
        echo -e '\nHit [Ctrl]+[D] to exit this child shell.'
        exec bash
    else
        echo -e "${RED}Error: Failed to clone the repository.${NC}"
    fi
}

help() {
    echo -e "\n${ORANGE}═══════════════════════${NC}"
    echo -e "${ORANGE}    GitS - Git Speed    ${NC}"
    echo -e "${ORANGE}═══════════════════════${NC}\n"
    echo -e "${PURPLE}Description:${NC} GitS is a tool for quickly combining git commands to speed up your workflow."
    echo -e "${PURPLE}Usage:${NC} gits <command>"
    echo
    echo -e "${PURPLE}Available commands:${NC}"
    echo -e "  ${GREEN}pull [branch]${NC} Quickly update your local repository"
    echo -e "             ${BLUE}Actions:${NC} checkout branch, stash changes, fetch, pull, show status"
    echo -e "             ${BLUE}Note:${NC} If no branch is specified, it defaults to 'development'"
    echo -e "             ${BLUE}Example:${NC} gits pull"
    echo -e "             ${BLUE}Example:${NC} gits pull main"
    echo
    echo -e "  ${GREEN}push${NC}          Rapidly stage, commit, and push changes"
    echo -e "             ${BLUE}Actions:${NC} add all changes, prompt for commit message, commit, push"
    echo -e "             ${BLUE}Note:${NC} Automatically sets upstream branch if not set"
    echo -e "             ${BLUE}Example:${NC} gits push"
    echo
    echo -e "  ${GREEN}pr <action>${NC}   Manage Pull Requests using Gitea Tea CLI"
    echo -e "             ${BLUE}Actions:${NC} create, close, merge"
    echo -e "             ${BLUE}Example:${NC} gits pr create (creates a new PR)"
    echo -e "             ${BLUE}Example:${NC} gits pr close (closes a PR)"
    echo -e "             ${BLUE}Example:${NC} gits pr merge (merges a PR)"
    echo
    echo -e "  ${GREEN}commit${NC}        Commit changes with a message"
    echo -e "             ${BLUE}Actions:${NC} prompt for commit message, commit"
    echo -e "             ${BLUE}Example:${NC} gits commit"
    echo
    echo -e "  ${GREEN}init${NC}          Initialize a new Git repository and push to GitHub"
    echo -e "             ${BLUE}Actions:${NC} init repo, create initial branch, add files, commit, push to GitHub"
    echo -e "             ${BLUE}Example:${NC} gits init"
    echo
    echo -e "  ${GREEN}new [name]${NC}    Create a new branch and switch to it"
    echo -e "             ${BLUE}Actions:${NC} create new branch, switch to it"
    echo -e "             ${BLUE}Note:${NC} If no name is provided, you'll be prompted to enter one"
    echo -e "             ${BLUE}Example:${NC} gits new"
    echo -e "             ${BLUE}Example:${NC} gits new feature-branch"
    echo
    echo -e "  ${GREEN}delete [branch-name]${NC} Delete a local branch and optionally delete it from remote"
    echo -e "             ${BLUE}Actions:${NC} Switch to default branch, delete specified branch, optionally delete from remote"
    echo -e "             ${BLUE}Note:${NC} If no branch name is provided, you'll be prompted to enter one"
    echo -e "             ${BLUE}Example:${NC} gits delete"
    echo -e "             ${BLUE}Example:${NC} gits delete feature-branch"
    echo
    echo -e "  ${GREEN}revert <number>${NC} Revert to a specified number of commits ago"
    echo -e "             ${BLUE}Actions:${NC} revert changes to the state X commits ago, stage changes"
    echo -e "             ${BLUE}Note:${NC} Changes are staged but not committed automatically"
    echo -e "             ${BLUE}Example:${NC} gits revert 1 (reverts the last commit)"
    echo -e "             ${BLUE}Example:${NC} gits revert 3 (reverts to 3 commits ago)"
    echo
    echo -e "  ${GREEN}unrevert${NC}      Cancel the last revert operation"
    echo -e "             ${BLUE}Actions:${NC} Undo the last revert if it hasn't been committed"
    echo -e "             ${BLUE}Example:${NC} gits unrevert"
    echo
    echo -e "  ${GREEN}clone <repo>${NC}  Clone a GitHub repository"
    echo -e "             ${BLUE}Actions:${NC} Clone the repository, switch to the repo directory"
    echo -e "             ${BLUE}Example:${NC} gits clone https://github.com/org/repo"
    echo -e "             ${BLUE}Example:${NC} gits clone org/repo (default to GitHub URL)"
    echo
    echo -e "  ${GREEN}install${NC}       Install GitS to /usr/local/bin (requires sudo)"
    echo -e "             ${BLUE}Example:${NC} gits install"
    echo
    echo -e "  ${GREEN}uninstall${NC}     Remove GitS from /usr/local/bin (requires sudo)"
    echo -e "             ${BLUE}Example:${NC} gits uninstall"
    echo
    echo -e "  ${GREEN}help${NC}          Display this help message"
    echo -e "             ${BLUE}Example:${NC} gits help"
    echo
    echo -e "${PURPLE}Note:${NC} Ensure you're in your git repository directory when running git-related commands."
}

# Main execution logic
main() {
    if [ $# -eq 0 ]; then
        help
        exit 1
    fi

    case "$1" in
        pr)
            shift
            pr "$@"
            ;;
        delete)
            shift
            delete "$@"
            ;;
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
        revert)
            shift
            revert "$@"
            ;;
        unrevert)
            unrevert
            ;;
        clone)
            shift
            clone "$@"
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
            echo -e "${GREEN}Unknown command:${NC} $1"
            echo "Run 'gits help' for usage information."
            exit 1
            ;;
    esac
}

# Run the main function
main "$@"