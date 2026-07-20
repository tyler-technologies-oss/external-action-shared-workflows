## Bash/Shell Review Standards

- Error handling: Flag any script missing set -euo pipefail near the top. Without -e failed commands are silently ignored; without -u unset variables expand empty; without -o pipefail only the last pipeline command determines success.
- Quoting: Flag any variable expansion not wrapped in double quotes ($var instead of "$var"). Unquoted variables cause word splitting and glob expansion.
- Command substitution: Flag unquoted command substitutions used as arguments (cmd $(other) instead of cmd "$(other)").
- Temporary files: Flag any temp file with a predictable path (e.g. /tmp/myscript.tmp). Require mktemp for all temporary files to prevent symlink attacks.
- Cleanup: Flag scripts that create temp files, subprocesses, or lock files without a trap cleanup EXIT handler.
- eval usage: Flag any use of eval on variables containing user input or external data. Require a justifying comment if eval is used.
- Unsafe input: Flag any unvalidated or unsanitized user input passed directly to commands.
- Portability: Flag bash-specific features ([[ ]], arrays, process substitution) in scripts with a #!/bin/sh shebang.
- Parsing ls: Flag any parsing of ls output. Use stat, find, or shell globs instead.
- Backticks: Flag backtick command substitution. Require $(cmd) syntax.
- Secrets: Flag any hardcoded secrets, passwords, tokens, or API keys.
- cd without restore: Flag functions using cd without restoring the original directory via pushd/popd or a subshell.

