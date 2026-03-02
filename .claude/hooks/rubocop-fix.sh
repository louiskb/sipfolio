#!/bin/bash
# Auto-corrects a Ruby file with RuboCop after Claude edits it.
# Only runs on .rb files. Silently skips everything else.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

if [[ "$FILE_PATH" == *.rb ]]; then
  cd "$(dirname "$FILE_PATH")" 2>/dev/null
  cd /Users/devilfish/code/chifury/sipfolio
  bundle exec rubocop --autocorrect --no-color "$FILE_PATH" 2>/dev/null
fi

exit 0
