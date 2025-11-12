# python-dev-standards
Repository for shared linting and formatting settings using 'ruff' and 'mypy'.

## Pre-commit Hooks

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

## Setting up Ruff for local development
Pre-commit hooks run in an isolated environment to check for formatting and type issues before committing changes, having Ruff and Mypy configured locally allows developers to catch and resolve issues in real-time as they write code. Below the steps to setup Ruff and Mypy for local development.

### Setup

1.  **Install `uv`:**
    `uv` is an extremely fast Python package installer and resolver, written in Rust.

    -   **Windows (PowerShell):**
        ```powershell
        irm https://astral.sh/uv/install.ps1 | iex
        ```
    -   **macOS / Linux:**
        ```bash
        curl -LsSf https://astral.sh/uv/install.sh | sh
        ```

2.  **Install Ruff:**
    Here we assume that you are in a repository that already contains the `pyproject.toml` file with `ruff` and `mypy` listed as dependencies. First thing to do is sync your environment so the dependencies are installed in your local virutal environment:

    ```bash
    uv sync
    ```

    In case ruff and mypy are not listed as dependencies you can add them:

      ```bash
    uv add ruff mypy
    ```

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


## Setting up Mypy for local development

This project uses [Mypy](http://mypy-lang.org/) for static type checking, which helps ensure type safety and prevent common bugs. The configuration is defined in the `mypy.ini` file.

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
