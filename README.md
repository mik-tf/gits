<h1> Git Speed (GitS) </h1>

<h2> Table of Contents</h2>

- [Introduction](#introduction)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Revert Function](#revert-function)
  - [Unrevert Function](#unrevert-function)
- [Uninstallation](#uninstallation)
- [Issues and Feature Requests](#issues-and-feature-requests)
- [Contributing](#contributing)
- [License](#license)

## Introduction

GitS is a bash script designed to streamline the Git workflow by combining common Git commands into quick, easy-to-use operations. It's perfect for developers who want to speed up their Git interactions and simplify their daily version control tasks.

## Features

- **Quick Pull**: Combines checkout, stash, fetch, pull, and status operations.
- **Rapid Push**: Stages all changes, prompts for a commit message, commits, and pushes in one command.
- **Easy Commit**: Quickly commit changes with a custom message.
- **Repository Initialization**: Initialize a new Git repository and push it to GitHub.
- **Branch Creation**: Create and switch to a new branch easily.
- **Commit Revert**: Revert to a specified number of commits ago.
- **Unrevert**: Cancel the last revert operation.
- **Clone**: Easily clone a GitHub repository and change to its directory.
- **Easy Installation**: Simple install and uninstall process.
- **User-Friendly**: Colorized output and helpful error messages.

## Installation

To install GitS, simply clone the repository and use the install command:

```bash
git clone https://github.com/Mik-TF/gits.git
cd gits
bash ./gits.sh install
```

This will copy the script to `/usr/local/bin/gits`, making it accessible system-wide. You'll need to enter your sudo password.

## Usage

After installation, you can use GitS from any directory with the following commands:

- `gits pull [branch]`: Quickly update your local repository
- `gits push`: Rapidly stage, commit, and push changes
- `gits commit`: Commit changes with a custom message
- `gits init`: Initialize a new Git repository and push to GitHub
- `gits new [name]`: Create a new branch and switch to it
- `gits revert <number>`: Revert to a specified number of commits ago
- `gits unrevert`: Cancel the last revert operation
- `gits help`: Display help information

For detailed usage information, run `gits help`.

### Revert Function

The `revert` function allows you to easily revert to a previous state:

```bash
gits revert <number>
```

- `<number>`: The number of commits to go back.
- Example: `gits revert 1` reverts the last commit
- Example: `gits revert 3` reverts to 3 commits ago

This command stages the revert changes but does not automatically commit them, allowing you to review the changes before committing.

### Unrevert Function

The `unrevert` function allows you to cancel the last revert operation:

```bash
gits unrevert
```

This command cancels the last revert if it hasn't been committed yet. It's useful if you accidentally revert changes and want to undo the revert operation.

## Uninstallation

To remove GitS from your system, run:

```bash
gits uninstall
```

This will remove the script from `/usr/local/bin/gits`. You'll need to enter your sudo password.

## Issues and Feature Requests

We use GitHub issues to track bugs and feature requests. If you encounter any problems or have ideas for improvements:

- **Bugs**: If you find a bug, please open an issue on our GitHub repository. Provide as much detail as possible, including your operating system, bash version, and steps to reproduce the bug.

- **Feature Requests**: Have an idea to make GitS even better? We'd love to hear it! Open an issue and label it as a feature request. Describe the feature you'd like to see, why you need it, and how it should work.

- **Questions**: If you have questions about using GitS, feel free to open an issue as well. We're here to help!

To create an issue, visit the [Issues page](https://github.com/Mik-TF/git_speed/issues) of our GitHub repository.

## Contributing

Contributions are welcome! If you'd like to contribute:

1. Fork the repository
2. Create your feature branch (`git checkout -b development_some_details`)
3. Commit your changes (`git commit -m 'Write a commit message'`)
4. Push to the branch (`git push origin development_some_details`)
5. Open a Pull Request

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.