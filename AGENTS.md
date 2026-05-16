# Repository Guidelines

## Project Structure & Module Organization

This repository currently has no committed source files. When you add code, keep a predictable layout so contributors can find things quickly. A common baseline is:

- `src/` for application or library code.
- `tests/` for automated tests and fixtures.
- `assets/` for static files (images, data, fonts).
- `docs/` for longer-form documentation.
- docs/仕様.md 作成するプログラムの仕様

If the project uses a different layout, document it here and update examples accordingly.

## Build, Test, and Development Commands

No build or test commands are configured yet. Once a toolchain is added, list the primary entry points here with short explanations, for example:

- `npm run dev` – start a local dev server.
- `npm test` – run the full test suite.
- `make build` – produce production artifacts.

Keep this list to the commands contributors will use most often.

## Coding Style & Naming Conventions

Define formatting rules once a language is chosen. At minimum, specify:

- Indentation (e.g., 2 spaces for JS/TS, 4 spaces for Python).
- Naming patterns (e.g., `camelCase` for variables, `PascalCase` for types, `snake_case` for files if applicable).
- Formatting/linting tools (e.g., Prettier, ESLint, black, gofmt) and how to run them.

## Testing Guidelines

Document the testing framework and conventions when tests are introduced. Include:

- Framework name (e.g., Jest, Pytest, Go test).
- File naming (e.g., `*.test.ts`, `test_*.py`).
- How to run tests locally and in CI.

## Commit & Pull Request Guidelines

There is no commit history in this repository yet. When work begins, adopt a consistent convention such as:

- `type(scope): summary` (e.g., `feat(api): add user endpoint`).

For pull requests, include:

- A concise description of what changed and why.
- Links to relevant issues or tickets.
- Screenshots or logs for user-facing or behavior changes.

## Security & Configuration Tips

If the project will require secrets or environment variables, document them in a template file like `/.env.example` and keep real secrets out of git.
