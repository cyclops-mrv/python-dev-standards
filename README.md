# python-dev-standards
Repository containing howto guides for python development and shared linting and formatting settings using `ruff` and `mypy`.

# Table of Contents

- [Using UV for Python Project & Environment Management](#using-uv-for-python-project--environment-management)
  - [📦 Install UV](#-install-uv)
  - [🚀 Initialize a New Project](#-initialize-a-new-project)
    - [Create a basic project](#create-a-basic-project)
    - [Project folder structure](#project-folder-structure)
  - [📓 Add Notebooks (Recommended Structure)](#-add-notebooks-recommended-structure)
  - [🐍 Create the Virtual Environment](#-create-the-virtual-environment)
  - [📚 Install Dependencies](#-install-dependencies)
    - [Install a runtime dependency](#install-a-runtime-dependency)
    - [Install a development-only dependency](#install-a-development-only-dependency)
    - [Import dependencies from requirements.txt](#import-dependencies-from-requirementstxt)
- [Python formatting and linting](#python-formatting-and-linting)
  - [🧹 Setting up Ruff for local development](#-setting-up-ruff-for-local-development)
    - [Setup](#setup)
    - [Manual Usage](#manual-usage)
      - [Format Code](#format-code)
      - [Check for Linting Issues](#check-for-linting-issues)
    - [VS Code Integration (Auto-formatting on Save)](#vs-code-integration-auto-formatting-on-save)
  - [🔍 Setting up Mypy for local development](#-setting-up-mypy-for-local-development)
    - [Setup and Dependency Management](#setup-and-dependency-management)
      - [Adding a New Dependency](#adding-a-new-dependency)
    - [Manual Usage](#manual-usage-1)
    - [VS Code Integration](#vs-code-integration)
  - [🪝 Pre-commit Hooks](#-pre-commit-hooks)
    - [Setup Instructions](#setup-instructions)
    - [Automatic Checks on Commit](#automatic-checks-on-commit)
    - [Manual Running of Hooks](#manual-running-of-hooks)
- [Private GitHub dependencies in Docker builds](#private-github-dependencies-in-docker-builds)
  - [Org prerequisites](#org-prerequisites)
  - [pyproject.toml](#pyprojecttoml)
  - [Dockerfile pattern](#dockerfile-pattern)
  - [Migration checklist](#migration-checklist)

# Using UV for Python Project & Environment Management

This guide explains how to install UV, set up a project, manage
environments, and install dependencies using modern Python packaging
practices.



## 📦 Install UV

UV is a fast Python package and environment manager from Astral. Install
it using one of the options below.

### Using Homebrew (macOS)

``` bash
brew install uv
```

### Using Curl (Linux/macOS)

``` bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```


## 🚀 Initialize a New Project

UV can generate a clean project structure following modern Python
packaging standards.

Create a new Python project (in this example we call the project cyclops-dev but this is arbitrary) managed by `uv`:

### Create a basic project

``` bash
uv init cyclops-devs --package
```
To specify a particular Python version:

``` bash
uv init cyclops-devs --package --python=3.12
```

### Project folder structure
After initialization, your folder will look like this:

    cyclops-dev
    ├── pyproject.toml
    ├── README.md
    └── src
        └── cyclops_dev
            └── __init__.py
    
- `pyproject.toml` — stores dependencies and project metadata.
- `src/` — contains your Python source code.

## 📓 Add Notebooks (Recommended Structure)

Keep notebooks separate from your package code to avoid mixing
experimental work with production modules.

    cyclops-dev
    ├── notebooks
    │   └── exploration.ipynb
    ├── pyproject.toml
    ├── README.md
    └── src
        └── cyclops_dev
            └── __init__.py

## 🐍 Create the Virtual Environment

UV automatically creates an isolated environment and installs
dependencies in one step. From your project root:

``` bash
uv sync
```

This generates:

    cyclops-dev
    ├── .venv
    ├── pyproject.toml
    ├── README.md
    └── src

This will:

- Create a `.venv/` folder

- Install dependencies from `pyproject.toml`

## 📚 Install Dependencies

Activate the environment:

``` bash
source .venv/bin/activate
```

### Install a runtime dependency
Add all the required dependency needed to deploy and run your code. This excludes development dependencies like jupyterlab and potentially matplotlib. These development dependencies might be used for research and development but are not required when deploying the code.

``` bash
uv add numpy
```

### Install a development-only dependency
Create a separate dependency list for additional dependencies that are only needed for your development environment. 
``` bash
uv add jupyterlab --dev
```

### Import dependencies from requirements.txt
In case you want migrate your dependencies from a `requirements.txt` file (used by `pip`) to a `pyproject.toml` (used by `uv`), you can use the following command:

``` bash
uv add -r requirements.txt
```
`uv` automatically updates your `pyproject.toml` with these dependencies.

# Python formatting and linting

## 🧹 Setting up Ruff for local development
Configuring Ruff locally allows developers to catch and resolve issues in real-time as they write code. Ruff is used for code formatting. Below the steps to setup Ruff for local development.

### Setup

1.  **Install Ruff:**
    Here we assume that you are in a repository that already contains the `pyproject.toml` file with `ruff` and `mypy` listed as dependencies. First thing to do is sync your environment so the dependencies are installed in your local virutal environment:

    ```bash
    uv sync
    ```

    In case ruff and mypy are not listed as dependencies you can add them the `linting` group:

      ```bash
    uv add --group linting ruff mypy
    ```

2.  **Copy the Ruff configuration file**: The Ruff formatting rules are specified in the `ruff.toml` file in this repository (`python-dev-standards`). Copy the [`ruff.toml`](https://github.com/cyclops-mrv/python-dev-standards/blob/main/ruff.toml) file from this repository to root directory of your own repository. 

### Manual Usage

You can run Ruff from your terminal to format code or check for issues.

#### Format Code

-   **Format the entire project:**
    ```bash
    ruff format .
    ```
-   **Format a specific folder:**
    ```bash
    ruff format path/to/your/folder/
    ```
-   **Format a single file:**
    ```bash
    ruff format path/to/your/file.py
    ```

#### Check for Linting Issues

-   **Check the entire project and apply automatic fixes:**
    ```bash
    ruff check . --fix
    ```
-   **Check a specific folder (without fixing):**
    ```bash
    ruff check path/to/your/folder/
    ```
-   **Check a single file (without fixing):**
    ```bash
    ruff check path/to/your/file.py
    ```

### VS Code Integration (Auto-formatting on Save)

1.  **Install the Ruff Extension:**
    Install the official [Ruff extension](https://marketplace.visualstudio.com/items?itemName=charliermarsh.ruff) from the VS Code Marketplace.

2.  **Configure VS Code Settings:**
    Create or open the `.vscode/settings.json` file in your project's root directory and add the following configuration. This ensures everyone on the team uses the same settings for this project.

    ```json
    {
      // Enable format on save for all files
      "editor.formatOnSave": true,

      // Set Ruff as the default formatter for Python files
      "[python]": {
        "editor.defaultFormatter": "charliermarsh.ruff"
      },

      // Run Ruff's "fixAll" and "organizeImports" actions on save.
      // This applies linting fixes before formatting.
      "editor.codeActionsOnSave": {
        "source.fixAll": "explicit",
        "source.organizeImports": "explicit"
      }
    }
    ```
    
## 🔍 Setting up Mypy for local development

This project uses [Mypy](http://mypy-lang.org/) for static type checking, which helps ensure type safety and prevent common bugs. The configuration is defined in the [`mypy.ini`](https://github.com/cyclops-mrv/python-dev-standards/blob/main/mypy.ini) file. Copy the `mypyp.ini` file to your repositories root directory.

### Setup and Dependency Management

All linting dependencies and stubs for `mypy` (`types-*` packages), are managed in the `pyproject.toml` file under the `[dependency-groups.linting]` group.

#### Adding a New Dependency

To add a new type stub for a library (e.g., `requests`) to the `linting` group, use the `uv add` command:

```bash
uv add types-requests --group linting
```
This will automatically update your `pyproject.toml` file.

### Manual Usage

To run `mypy`:

-   **Check the entire project:**
    ```bash
    mypy .
    ```
-   **Check a specific folder:**
    ```bash
    mypy path/to/your/folder/
    ```
-   **Check a single file:**
    ```bash
    mypy path/to/your/file.py

### VS Code Integration

1.  **Install the Mypy Type Checker Extension:**
    Install the official [Mypy Type Checker extension](https://marketplace.visualstudio.com/items?itemName=ms-python.mypy-type-checker) from the VS Code Marketplace.


## 🪝 Pre-commit Hooks

Our repositories use [pre-commit](https://pre-commit.com/) to automatically check code formatting and type annotations before committing changes. The hooks configured in the `.pre-commit-config.yaml` file ensure that:

- **Ruff** runs to check for code style issues and automatically fix them.
- **Mypy** checks for type annotations and ensures type safety.

### Setup Instructions

1. **Install Pre-commit:**
   If you haven't already, install the `pre-commit` package:

   ```bash
   pip install pre-commit
   ```

2. **Install the Hooks:**
   Run the following command to install the hooks defined in your `.pre-commit-config.yaml`:

   ```bash
   pre-commit install
   ```

### Automatic Checks on Commit

Once the hooks are installed, they will automatically run every time you attempt to commit changes. This means you don't have to manually run `ruff` or `mypy`—the pre-commit hooks will handle it for you. If there are any issues found by Ruff or Mypy, the commit will be blocked until those issues are resolved.

### Manual Running of Hooks

If you want to run the hooks manually at any time, you can do so with the following commands:

- **Run all hooks on all files:**

  ```bash
  pre-commit run --all-files
  ```

- **Run a specific hook (e.g., Mypy):**

  ```bash
  pre-commit run mypy --all-files
  ```

- **Run a specific hook (e.g., Ruff):**

  ```bash
  pre-commit run ruff --all-files
  ```

# Private GitHub dependencies in Docker builds

Projects that call the reusable [`deploy-prefect-flow.yml`](.github/workflows/deploy-prefect-flow.yml) workflow can install private org git dependencies during Docker image builds using a GitHub App token — no SSH deploy keys required.

## Org prerequisites

Configure these at the GitHub organization level:

- **Variable** `GH_APP_ID` — GitHub App ID
- **Secret** `GH_APP_PRIVATE_KEY` — GitHub App private key (PEM)
- GitHub App installed org-wide with **Contents: Read** access to private repositories

After all consumer repos are migrated, retire the legacy `DEPLOY_SSH_KEY` secret.

## pyproject.toml

Keep private git dependencies as normal HTTPS or SSH URLs. Do not commit tokens or placeholders — the Dockerfile injects authentication at build time.

```toml
[project]
dependencies = ["my-private-lib"]

[tool.uv.sources]
my-private-lib = { git = "https://github.com/org/my-private-lib.git", tag = "v1.0.0" }
# or, if migrating from SSH:
# my-private-lib = { git = "ssh://git@github.com/org/my-private-lib.git", tag = "v1.0.0" }
```

Local development continues to work via SSH keys or `gh auth setup-git`; CI and Docker use the build-secret pattern below.

## Dockerfile pattern

Replace `RUN --mount=type=ssh` (and any `openssh-client` / `known_hosts` setup) with:

```dockerfile
# syntax=docker/dockerfile:1

COPY pyproject.toml .

RUN --mount=type=secret,id=github_token \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) && \
    sed -i "s|ssh://git@github.com/|https://x-access-token:${GITHUB_TOKEN}@github.com/|g" pyproject.toml && \
    sed -i "s|https://github.com/|https://x-access-token:${GITHUB_TOKEN}@github.com/|g" pyproject.toml && \
    uv pip install --system -r pyproject.toml
```

Notes:

- The `github_token` build secret is injected by `deploy-prefect-flow.yml`; consumer repos do not define it in their own workflows.
- `GITHUB_TOKEN` is a shell variable scoped to that single `RUN` step; the secret file is never copied into the image.
- The two `sed` commands cover both legacy SSH git URLs and plain HTTPS URLs in `pyproject.toml`.
- Set `ENV UV_SYSTEM_PYTHON=1` (or use `--system` as shown) when installing into the system Python in slim base images.
- Copy `pyproject.toml` before this step; avoid re-copying an unmodified `pyproject.toml` over the sed-modified file in later layers if subsequent install steps depend on authenticated URLs.

If a project uses `uv sync` instead of `uv pip install`, apply the same `--mount=type=secret,id=github_token` + `sed` pattern in the same `RUN` as the sync command (sed first, then `uv sync`).

## Migration checklist

For each repo calling `deploy-prefect-flow.yml`:

1. Ensure private git deps in `pyproject.toml` use `https://github.com/...` or `ssh://git@github.com/...` (no embedded tokens).
2. Update `deployment/Dockerfile`: drop SSH mounts; add the sed + `uv pip install --system -r pyproject.toml` pattern (or sed + `uv sync` if that is what the Dockerfile uses).
3. Re-run the deploy workflow to verify the image build succeeds.
4. Remove per-repo deploy keys / `DEPLOY_SSH_KEY` once all repos are migrated.

