#!/bin/bash
# Double-click or run from terminal daily to commit ONE real project file and push.
# Gives you one GitHub contribution per day.

cd "$(dirname "$0")"

# Check if git repo exists
if [ ! -d ".git" ]; then
    echo "ERROR: No git repo found. Run 'git init' first."
    exit 1
fi

# Check if remote is configured
if ! git remote -v 2>/dev/null | grep -q "origin"; then
    echo "ERROR: No git remote configured."
    echo "Run: git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
    exit 1
fi

# Get list of untracked files (files only, no directories) and modified files
FILES=()
while IFS= read -r f; do
    FILES+=("$f")
done < <(
    git ls-files --others --exclude-standard | while IFS= read -r f; do
        [ -f "$f" ] && echo "$f"
    done
    git diff --name-only
)

COUNT=${#FILES[@]}

if [ "$COUNT" -eq 0 ]; then
    echo ""
    echo "============================================"
    echo " All files have been committed! Nothing left to push."
    echo "============================================"
    echo ""
    exit 0
fi

# Pick the first file
PICK="${FILES[0]}"
TODAY=$(date +%Y-%m-%d)

echo ""
echo "Adding: $PICK"
echo ""

git add "$PICK" || { echo "ERROR: git add failed for: $PICK"; exit 1; }
git commit -m "Add $PICK - $TODAY" || { echo "ERROR: git commit failed."; exit 1; }
git push -u origin main || { echo "ERROR: git push failed. Check your remote/credentials."; exit 1; }

echo ""
echo "============================================"
echo " Pushed: $PICK"
echo " Files remaining: $((COUNT - 1))"
echo "============================================"
echo ""
