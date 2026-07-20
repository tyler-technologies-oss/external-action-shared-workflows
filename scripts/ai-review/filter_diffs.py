"""
Pre-fetch diff filter: reads /tmp/pr_all_files.json and writes
per-type diff files to /tmp/pr_diffs_{type}.txt.

Called by the Pre-fetch PR Diffs step in action.yml.
Environment variables used: REVIEW_SCOPE

The 'general' type is a catch-all: when active alongside other types
it only receives files NOT already claimed by a specific type.
When active alone it covers everything except docs/images/lockfiles.
"""
import json
import os
import sys

with open('/tmp/pr_all_files.json') as f:
    files = json.load(f)

review_scope = os.environ.get('REVIEW_SCOPE', 'supplychain').lower().strip()
if review_scope == 'all':
    active_types = ['supplychain', 'bash', 'javascript', 'docker', 'python', 'go', 'powershell', 'general']
else:
    active_types = [t.strip() for t in review_scope.split(',')]

TYPE_CONFIG = {
    'supplychain': {
        'extensions': ['.yml', '.yaml', '.sh', '.bash', '.js', '.ts', '.mjs', '.cjs', '.json'],
        'literals': ['Dockerfile', 'Makefile', 'action.yml', 'action.yaml',
                     'CODEOWNERS', 'SECURITY.md'],
        'skip_dirs': ['node_modules/'],
        'skip_ext': [],
        'skip_files': ['package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'go.sum'],
    },
    'bash': {
        'extensions': ['.sh', '.bash'],
        'literals': ['Makefile'],
        'skip_dirs': [],
        'skip_ext': [],
    },
    'javascript': {
        'extensions': ['.js', '.ts', '.mjs', '.cjs'],
        'literals': ['package.json'],
        'skip_dirs': ['node_modules/', '/dist/'],
        'skip_ext': [],
    },
    'docker': {
        'extensions': ['.dockerfile'],
        'literals': ['Dockerfile'],
        'skip_dirs': [],
        'skip_ext': [],
    },
    'python': {
        'extensions': ['.py'],
        'literals': ['requirements.txt', 'pyproject.toml', 'setup.py'],
        'skip_dirs': [],
        'skip_ext': [],
    },
    'go': {
        'extensions': ['.go'],
        'literals': ['go.mod'],
        'skip_dirs': [],
        'skip_ext': [],
        'skip_files': ['go.sum'],
    },
    'powershell': {
        'extensions': ['.ps1', '.psm1', '.psd1'],
        'literals': [],
        'skip_dirs': [],
        'skip_ext': [],
    },
    # general is a catch-all: matches everything not already covered,
    # skipping only pure docs/images/lockfiles that aren't worth reviewing.
    'general': {
        'extensions': [],
        'literals': [],
        'skip_dirs': [],
        'skip_ext': ['.md', '.txt', '.rst', '.png', '.jpg', '.jpeg',
                     '.gif', '.svg', '.ico', '.webp'],
        'skip_files': ['package-lock.json', 'yarn.lock', 'pnpm-lock.yaml',
                       '.DS_Store'],
    },
}

ALWAYS_SKIP_BASENAMES = {'.gitignore', '.env', '.env.example'}


def file_matches(fname, cfg):
    basename = fname.split('/')[-1]
    if basename in ALWAYS_SKIP_BASENAMES:
        return False
    for ext in cfg.get('skip_ext', []):
        if fname.endswith(ext):
            return False
    for sf in cfg.get('skip_files', []):
        if basename == sf:
            return False
    for d in cfg.get('skip_dirs', []):
        if d in fname:
            return False
    exts = cfg['extensions']
    literals = cfg['literals']
    # No extension/literal constraints = match everything (used by general)
    if not exts and not literals:
        return True
    if basename in literals:
        return True
    for ext in exts:
        if fname.endswith(ext):
            return True
    return False


def annotate_patch(patch):
    """Prepend the file line number to every + and context line in a unified diff.

    The Read tool shows document-level line numbers (position in pr_diffs_*.txt),
    which are NOT the same as the GitHub file line numbers needed for inline comments.
    Embedding the file line number directly eliminates any arithmetic on Claude's part.

    Output format for each line:
      L  42 +added line content
      L  43  context line
           -deleted line content   (no file line — deleted lines don't exist in the new file)
    """
    import re
    if not patch or patch.startswith('(no diff'):
        return patch

    lines = patch.split('\n')
    result = []
    file_line = 0

    for line in lines:
        if line.startswith('@@'):
            m = re.search(r'\+(\d+)', line)
            if m:
                file_line = int(m.group(1))
            result.append(line)
        elif line.startswith('+'):
            result.append(f'L{file_line:5d} {line}')
            file_line += 1
        elif line.startswith('-'):
            result.append(f'       {line}')
        elif line.startswith(' '):
            result.append(f'L{file_line:5d} {line}')
            file_line += 1
        else:
            result.append(line)

    return '\n'.join(result)


def write_diffs(out_path, matching):
    if not matching:
        with open(out_path, 'w') as out:
            out.write('No files found in this PR for this review type.\n')
        return 0
    with open(out_path, 'w') as out:
        out.write(f'# {len(matching)} files to review\n\n')
        for f in matching:
            fname = f['filename']
            status = f.get('status', 'modified')
            adds = f.get('additions', 0)
            dels = f.get('deletions', 0)
            patch = f.get('patch') or '(no diff - binary or file too large for API)'
            out.write(f'=== FILE: {fname} (status: {status}, +{adds}/-{dels}) ===\n')
            out.write(annotate_patch(patch))
            out.write('\n\n')
    return len(matching)


# Track filenames claimed by specific types so general can be a true catch-all
covered_filenames = set()

# Process specific types first (all except general)
specific_types = [t for t in active_types if t != 'general']
for type_name in specific_types:
    cfg = TYPE_CONFIG.get(type_name)
    if not cfg:
        print(f'  {type_name}: unknown type, skipping', file=sys.stderr)
        continue
    out_path = f'/tmp/pr_diffs_{type_name}.txt'
    matching = [f for f in files if file_matches(f['filename'], cfg)]
    count = write_diffs(out_path, matching)
    for f in matching:
        covered_filenames.add(f['filename'])
    print(f'  {type_name}: {count} files -> {out_path}')

# Process general last — only files not already covered by a specific type
if 'general' in active_types:
    cfg = TYPE_CONFIG['general']
    out_path = '/tmp/pr_diffs_general.txt'
    # Exclude files already claimed by specific types
    matching = [
        f for f in files
        if f['filename'] not in covered_filenames and file_matches(f['filename'], cfg)
    ]
    count = write_diffs(out_path, matching)
    print(f'  general: {count} files (catch-all) -> {out_path}')
