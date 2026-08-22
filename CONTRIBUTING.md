# Contributing to the Ascender Installer

Thanks for your interest in contributing to the Ascender Installer. This document covers the
development setup, testing, and pull request guidelines.

## Development setup

Fork and clone the repository:

```bash
git clone https://github.com/<your-user>/ascender-install.git
cd ascender-install
```

The installer runs from a checkout, so there is nothing to build. Point the
inventory at a disposable host and generate a config:

```bash
./config_vars.sh
./setup.sh
```

## Running tests

There is no automated suite. Verify changes with a real install against at
least one Kubernetes platform, and say in the PR which platform you tested.
Changes touching a single platform's role should not alter the others.


## Making changes

### Branching

Create a feature branch from `main`:

```bash
git checkout -b my-feature main
```

### Commit messages

Write clear, concise commit messages:

```
Short summary (under 72 characters)

Longer description of what changed and why, if needed.
```

## Submitting a PR

1. Make sure the checks above pass locally.
2. One logical change per PR. Do not bundle unrelated fixes.
3. Target the `main` branch.
4. Explain what changed and why in the PR description.

## Reporting issues

Open an issue at
[github.com/ctrliq/ascender-install/issues](https://github.com/ctrliq/ascender-install/issues).
Include the version you are running and the steps that reproduce the problem.

For security vulnerabilities, follow [SECURITY.md](./SECURITY.md) instead of
opening a public issue.
