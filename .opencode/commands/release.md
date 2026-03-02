---description: Create a versioned release (bump, commit, tag, push)argument-hint: "[major|minor|patch]"agent: build---
You are a release automation assistant. Follow the steps below precisely.
## Context
Current git branch:
!`git branch --show-current`
Working tree status:
!`git status --porcelain`
Existing release tags (three-component semver only):
!`git tag -l 'v*.*.*' --sort=-v:refname`
Commits since the last release tag:
!`latest=$(git tag -l 'v*.*.*' --sort=-v:refname | head -1); if [ -n "$latest" ]; then git log "$latest"..HEAD --format="%s (%h)"; else git log --format="%s (%h)"; fi`
## Step 1: Pre-flight checks
- If there are uncommitted changes (non-empty working tree status above), **abort** and tell the user to commit or stash first.
- If there are no commits since the last release tag, **abort** and tell the user there is nothing to release.
## Step 2: Determine bump type
There are three possible paths. Check them in this order:
### Path A: Explicit argument
If the user provided `$ARGUMENTS` and it is one of `major`, `minor`, or `patch`, use that directly. Skip analysis and confirmation.
### Path B: Subsequent alpha on a feature branch
If **all** of these are true:
- The current branch is **not** `main`.
- The current version already has an `-alpha.N` suffix (check existing tags).
Then this is a follow-up alpha release. **Skip commit analysis entirely.** Use the existing base version and just increment the alpha number (handled in Step 3). Tell the user briefly, e.g.:
> Continuing alpha series for 0.2.0. Next: v0.2.0-alpha.3
### Path C: Analyze commits (main branch, or first release on a feature branch)
This applies when:
- We are on `main`, OR
- We are on a feature branch but this is the first pre-release for a new version.
Analyze the commits since the last release tag and suggest a semver bump:
- **major**: if any commit message contains `BREAKING CHANGE` or uses the `!` convention (e.g., `feat!:`, `fix!:`).
- **minor**: if any commit message starts with `feat:` or `feat(`.
- **patch**: if all commits are `fix:`, `chore:`, `refactor:`, `docs:`, `style:`, `perf:`, `test:`, `build:`, `ci:`, or similar non-feature work.
Present your suggestion to the user with a brief summary of the commits that led to it. Then use the question tool to let the user confirm or override. Offer these options:
- Your suggested bump type (mark as recommended)
- The other two bump types
## Step 3: Calculate the new version
1. Get the latest tag (or use "0.0.0" if no tags exist).
2. Strip any pre-release suffix (e.g., `-alpha.1`) to get the **base version**.
3. Apply the selected bump to the base version:
   - `patch`: `0.0.1` -> `0.0.2`
   - `minor`: `0.0.1` -> `0.1.0`
   - `major`: `0.0.1` -> `1.0.0`
4. Determine if this is a pre-release:
   - If the current branch is **not** `main`: this is an **alpha** pre-release.
     - Check existing git tags matching `v{bumped_base}-alpha.*`.
     - Find the highest alpha number `N`.
     - New version = `{bumped_base}-alpha.{N+1}` (or `-alpha.1` if none exist).
   - If the current branch **is** `main`: new version = `{bumped_base}` (no suffix).
## Step 4: Execute the release
Run these steps sequentially:
1. Update the version field in Info.plist to the new version (edit the file, do not rewrite it).
2. Stage and commit: `git add -A && git commit -m "release: v{new_version}"`
3. Create an annotated tag: `git tag -a v{new_version} -m "v{new_version}"`
4. Push: `git push && git push --tags`
## Step 5: Report
Tell the user:
- The new version that was tagged (e.g., `v0.1.0` or `v0.2.0-alpha.1`).
- Whether it's a full release or an alpha pre-release.
- Remind them that the GitHub Actions workflow will build and publish the release artifacts.
## Rules
- Only three-component semver tags (`vX.Y.Z` or `vX.Y.Z-alpha.N`) are release tags. Ignore two-component tags like `v1.2` (those are milestone markers).
- The version in Info.plist must always match the git tag (without the `v` prefix).
- Never force-push.
