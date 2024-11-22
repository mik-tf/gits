#!/bin/bash

# ANSI color codes
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[38;5;208m'
NC='\033[0m' # No Color

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

# Function to clone all repositories for a GitHub/Gitea username via SSH
clone-all() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Please provide a username.${NC}"
        echo -e "Usage: gits clone-all <username>"
        return 1
    fi

    echo -e "${GREEN}Which platform would you like to use?${NC}"
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    local USERNAME="$1"

    # Set platform-specific variables
    case "$platform_choice" in
        1)
            git_url="git@git.ourworld.tf"
            ;;
        2)
            git_url="git@github.com"
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            return 1
            ;;
    esac

    # Create a directory for cloning
    mkdir -p "$USERNAME"
    cd "$USERNAME" || return 1

    echo -e "${GREEN}Cloning all repositories for user: $USERNAME${NC}"

    # Track successful and failed clones
    local successful_clones=0
    local failed_clones=0
    local total_repos=0

    # Fetch repository list using platform-specific API with pagination
    local page=1
    while true; do
        # Fetch repositories for the current page based on platform
        local REPOS_JSON
        if [ "$platform_choice" = "1" ]; then
            REPOS_JSON=$(curl -s "https://git.ourworld.tf/api/v1/users/$USERNAME/repos?per_page=100&page=$page")
        else
            REPOS_JSON=$(curl -s "https://api.github.com/users/$USERNAME/repos?per_page=100&page=$page")
        fi
        
        # Extract repository names
        local REPOS=$(echo "$REPOS_JSON" | jq -r '.[].name')
        
        # Break if no more repositories
        if [ -z "$REPOS" ]; then
            break
        fi
        
        # Clone each repository
        for repo in $REPOS; do
            ((total_repos++))
            
            # Sanitize repository name
            local safe_repo=$(echo "$repo" | sed 's/[^a-zA-Z0-9._-]/_/g')
            
            # Skip if repository directory already exists
            if [ -d "$safe_repo" ]; then
                echo -e "${ORANGE}Repository $repo already exists. Skipping...${NC}"
                continue
            fi
            
            echo -e "${PURPLE}Cloning $repo...${NC}"
            
            # Attempt to clone via SSH
            if git clone "$git_url:$USERNAME/$repo.git" "$safe_repo"; then
                ((successful_clones++))
                echo -e "${GREEN}Completed cloning $repo${NC}"
            else
                ((failed_clones++))
                echo -e "${RED}Failed to clone $repo${NC}"
            fi
        done
        
        # Increment page number
        ((page++))
    done

    # Display summary
    echo -e "\n${BLUE}Cloning Summary:${NC}"
    echo -e "Total Repositories: ${total_repos}"
    echo -e "${GREEN}Successfully Cloned: ${successful_clones}${NC}"
    echo -e "${RED}Failed to Clone: ${failed_clones}${NC}"
    
    # Return to original directory
    cd - > /dev/null
}

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

# Function to handle repository operations
repo() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Please specify an action (create/delete)${NC}"
        echo -e "Usage: gits repo <create|delete>"
        return 1
    fi

    case "$1" in
        create)
            repo_create
            ;;
        delete)
            repo_delete
            ;;
        *)
            echo -e "${RED}Invalid action. Use create or delete${NC}"
            return 1
            ;;
    esac
}

# Function to create a repository
repo_create() {
    echo -e "${GREEN}Which platform would you like to use?${NC}"
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    echo -e "${GREEN}Enter repository name:${NC}"
    read repo_name

    echo -e "${GREEN}Enter repository description:${NC}"
    read description

    echo -e "${GREEN}Make repository private? (y/n):${NC}"
    read is_private

    case "$platform_choice" in
        1)
            visibility=""
            if [[ $is_private == "y" ]]; then
                visibility="--private"
            else
                visibility="--public"
            fi

            echo -e "\n${PURPLE}Creating repository on Gitea...${NC}"
            if tea repo create --name "$repo_name" --description "$description" $visibility; then
                echo -e "${GREEN}Repository created successfully on Gitea!${NC}"
            else
                echo -e "${RED}Failed to create repository on Gitea.${NC}"
            fi
            ;;
        2)
            visibility=""
            if [[ $is_private == "y" ]]; then
                visibility="--private"
            else
                visibility="--public"
            fi

            echo -e "\n${PURPLE}Creating repository on GitHub...${NC}"
            if gh repo create "$repo_name" --description "$description" $visibility --confirm; then
                echo -e "${GREEN}Repository created successfully on GitHub!${NC}"
            else
                echo -e "${RED}Failed to create repository on GitHub.${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            return 1
            ;;
    esac
}

# Function to delete a repository
repo_delete() {
    echo -e "${GREEN}Which platform would you like to use?${NC}"
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    case "$platform_choice" in
        1)
            echo -e "${GREEN}Enter repository (organization/repository):${NC}"
            read repo_name

            echo -e "${RED}WARNING: This action cannot be undone!${NC}"
            echo -e "${GREEN}Are you sure you want to delete $repo_name? (y/n):${NC}"
            read confirm

            if [[ $confirm == "y" ]]; then
                echo -e "\n${PURPLE}Deleting repository from Gitea...${NC}"
                if tea repo delete "$repo_name" --confirm; then
                    echo -e "${GREEN}Repository deleted successfully from Gitea!${NC}"
                else
                    echo -e "${RED}Failed to delete repository from Gitea.${NC}"
                fi
            fi
            ;;
        2)
            echo -e "${GREEN}Enter repository name:${NC}"
            read repo_name

            echo -e "${RED}WARNING: This action cannot be undone!${NC}"
            echo -e "${GREEN}Are you sure you want to delete $repo_name? (y/n):${NC}"
            read confirm

            if [[ $confirm == "y" ]]; then
                echo -e "\n${PURPLE}Deleting repository from GitHub...${NC}"
                if gh repo delete "$repo_name" --confirm; then
                    echo -e "${GREEN}Repository deleted successfully from GitHub!${NC}"
                else
                    echo -e "${RED}Failed to delete repository from GitHub.${NC}"
                fi
            fi
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            return 1
            ;;
    esac
}

# Function to initialize a new Git repository and push to GitHub or Gitea
init() {
    echo -e "${GREEN}Which platform would you like to use?${NC}"
    echo -e "1) Gitea (git.ourworld.tf)"
    echo -e "2) GitHub (github.com)"
    read -p "Enter your choice (1/2): " platform_choice

    # Set platform-specific variables
    case "$platform_choice" in
        1)
            git_url="https://git.ourworld.tf"
            initial_branch="development"
            platform="Gitea"
            ;;
        2)
            git_url="https://github.com"
            initial_branch="main"
            platform="GitHub"
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            return 1
            ;;
    esac

    echo -e "${GREEN}Initializing new Git repository...${NC}"
    
    echo -e "Enter your $platform username:"
    read username
    echo -e "Enter the repository name:"
    read repo_name

    echo -e "${GREEN}Make sure to create a repository on $platform with the proper username (${username}) and repository (${repo_name})${NC}"
    echo -e "Press Enter when you're ready to continue..."
    read

    git init

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

    git remote add origin "$git_url/$username/$repo_name.git"
    git push -u origin $initial_branch

    echo -e "${PURPLE}Repository initialized and pushed to $platform successfully.${NC}"
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

# Function to handle login
login() {
    echo -e "${GREEN}Which platform would you like to login to?${NC}"
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    case "$platform_choice" in
        1)
            echo -e "${PURPLE}Logging into Gitea...${NC}"
            tea login add
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Successfully logged into Gitea.${NC}"
            else
                echo -e "${RED}Failed to login to Gitea.${NC}"
            fi
            ;;
        2)
            echo -e "${PURPLE}Logging into GitHub...${NC}"
            gh auth login
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Successfully logged into GitHub.${NC}"
            else
                echo -e "${RED}Failed to login to GitHub.${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            return 1
            ;;
    esac
}

# Function to handle logout
logout() {
    echo -e "${GREEN}Which platform would you like to logout from?${NC}"
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    case "$platform_choice" in
        1)
            echo -e "${PURPLE}Logging out from Gitea...${NC}"
            tea logout
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Successfully logged out from Gitea.${NC}"
            else
                echo -e "${RED}Failed to logout from Gitea.${NC}"
            fi
            ;;
        2)
            echo -e "${PURPLE}Logging out from GitHub...${NC}"
            gh auth logout
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Successfully logged out from GitHub.${NC}"
            else
                echo -e "${RED}Failed to logout from GitHub.${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            return 1
            ;;
    esac
}

# Function to install the script
install() {
    echo
    echo -e "${GREEN}Installing GitS...${NC}"
    if sudo -v; then
        sudo cp "$0" /usr/local/bin/gits
        sudo chown root:root /usr/local/bin/gits
        sudo chmod 755 /usr/local/bin/gits

        echo
        echo -e "${PURPLE}GitS has been installed successfully.${NC}"
        echo -e "You can now use ${GREEN}gits${NC} command from anywhere."
        echo
        echo -e "Use ${BLUE}gits help${NC} to see the commands."
        echo
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Installation aborted.${NC}"
        exit 1
    fi
}

# Function to uninstall the script
uninstall() {
    echo
    echo -e "${GREEN}Uninstalling GitS...${NC}"
    if sudo -v; then
        sudo rm -f /usr/local/bin/gits
        echo -e "${PURPLE}GitS has been uninstalled successfully.${NC}"
        echo
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Uninstallation aborted.${NC}"
        exit 1
    fi
}

help() {
    echo -e "\n${ORANGE}═══════════════════════${NC}"
    echo -e "${ORANGE}    GitS - Git Speed    ${NC}"
    echo -e "${ORANGE}═══════════════════════${NC}\n"
    echo -e "${PURPLE}Description:${NC} GitS is a Bash CLI tool for speeding up common git/gh/tea operations by combining multiple commands."
    echo -e "${PURPLE}Usage:${NC} gits <command>"
    echo -e "${PURPLE}License:${NC} Apache 2.0"
    echo -e "${PURPLE}Code:${NC} https://github.com/Mik-TF/gits.git"
    
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
    echo -e "  ${GREEN}repo <action>${NC}  Manage repositories"
    echo -e "             ${BLUE}Actions:${NC} create, delete"
    echo -e "             ${BLUE}Example:${NC} gits repo create (creates a new repository)"
    echo -e "             ${BLUE}Example:${NC} gits repo delete (deletes a repository)"
    echo
    echo -e "  ${GREEN}init${NC}          Initialize a new Git repository and push to GitHub or Gitea"
    echo -e "             ${BLUE}Actions:${NC} Choose platform (Gitea/GitHub), init repo, create initial branch, add files, commit, push"
    echo -e "             ${BLUE}Note:${NC} Default branch is 'development' for Gitea and 'main' for GitHub"
    echo -e "             ${BLUE}Note:${NC} Gitea URL will be git.ourworld.tf"
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
    echo -e "  ${GREEN}login${NC}         Login to Gitea or GitHub"
    echo -e "             ${BLUE}Actions:${NC} Interactive login to selected platform"
    echo -e "             ${BLUE}Example:${NC} gits login"
    echo
    echo -e "  ${GREEN}logout${NC}        Logout from Gitea or GitHub"
    echo -e "             ${BLUE}Actions:${NC} Logout from selected platform"
    echo -e "             ${BLUE}Example:${NC} gits logout"
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
        login)
            login
            ;;
        logout)
            logout
            ;;
        repo)
            shift
            repo "$@"
            ;;
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
        clone-all)
            shift
            clone-all "$@"
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