## General Review Criteria
- New executables or blobs: Note added binary files, or large base64/hex blobs in any text file, outside known build output. RISKY: new tools/helper binary with no source  SAFER: source-only additions
- Governance file reductions: Note changes to FORK_MANIFEST.json, CODEOWNERS, SECURITY.md, or issue/PR templates that narrow review coverage or remove owners. RISKY: CODEOWNERS entry for .github/ deleted  SAFER: coverage unchanged or broadened
- Diff-hiding config: Note .gitattributes/.gitignore changes that mark files generated/binary or ignore previously tracked paths. RISKY: scripts/** linguist-generated=true  SAFER: no visibility changes
- In-tree hooks and symlinks: Note added git hooks (husky, core.hooksPath) or symlinks pointing outside the repo. RISKY: symlink config -> /etc/passwd  SAFER: regular files only
- Docs steering users to run code: Note README/docs changed to instruct curl | bash from new domains or to disable verification steps. RISKY: install one-liner domain changed  SAFER: instructions match pinned releases
- Purpose drift: Note files changed in ways unrelated to their stated purpose. RISKY: .editorconfig replaced by a YAML with run: content  SAFER: change matches file purpose
