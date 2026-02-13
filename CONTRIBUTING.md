# Contributing to DNS Hardening for Parrot OS

First off, thank you for considering contributing! This project thrives on community involvement, and every contribution is appreciated.

This document provides guidelines for contributing to the project.

## ❓ How to Report an Issue

If you find a bug, have a feature request, or want to suggest an improvement, please [**open an issue on GitHub**](https://github.com/cyclonite69/dns-hardening-parrot/issues).

When filing a bug report, please include the following to help us resolve it quickly:
-   A clear and descriptive title.
-   A detailed description of the problem, including the script you were running and the behavior you observed.
-   Steps to reproduce the issue.
-   The output of the script and any relevant log files.
-   Your operating system and version.

## 🚀 How to Submit a Pull Request (PR)

We welcome pull requests for bug fixes, new features, and documentation improvements.

1.  **Fork the repository** to your own GitHub account.
2.  **Create a new branch** for your changes. Use a descriptive name (e.g., `feat/add-new-service-check` or `fix/docker-dns-revert-bug`).
    ```bash
    git checkout -b your-branch-name
    ```
3.  **Make your changes**. Ensure your code adheres to the style guidelines below.
4.  **Test your changes** thoroughly.
5.  **Commit your changes** with a clear and descriptive commit message.
    ```bash
    git commit -m "feat: Add check for XYZ service"
    ```
6.  **Push your branch** to your fork.
    ```bash
    git push origin your-branch-name
    ```
7.  **Open a Pull Request** from your fork to the `master` branch of this repository.
8.  In the PR description, clearly explain the problem you are solving and the changes you have made. Link to any relevant issues.

##  coding-style Code Style Guidelines

To maintain a consistent and readable codebase, please follow these guidelines:

-   **Shell Scripts**:
    -   All scripts must start with `set -euo pipefail` for robustness.
    -   Follow the existing style for variable names (`UPPER_CASE` for constants, `lower_case` for locals), function names (`lower_case`), and logging/output formatting.
    -   Add comments to explain complex or non-obvious logic.
-   **Markdown Files**:
    -   Follow standard Markdown best practices.
    -   Use code blocks with language identifiers for syntax highlighting.

## ✅ Testing Requirements

-   **New Features**: Any new feature should be tested on a clean installation of Parrot OS or a similar Debian-based system. Describe the testing you have performed in your PR.
-   **Bug Fixes**: If you are fixing a bug, please provide steps to reproduce the bug and verify that your fix resolves it.
-   **Existing Functionality**: Ensure that your changes do not break any existing functionality. Run the other scripts in the repository to confirm they still work as expected.

Thank you again for your contribution!
