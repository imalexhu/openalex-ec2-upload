#!/bin/bash

echo "Printing all source files with line counts and contents..."
echo "==========================================================="

# Define file types to include
EXTENSIONS=("*.py" "*.sh" "*.sql")

for ext in "${EXTENSIONS[@]}"; do
  echo ""
  echo "=== Searching for files matching: $ext ==="
  echo ""

  while IFS= read -r -d '' file; do
    line_count=$(wc -l < "$file")
    echo "-------------------------------------------------------"
    echo "📄 File: $file"
    echo "📏 Lines: $line_count"
    echo "-------------------------------------------------------"
    cat "$file"
    echo -e "\n\n"
  done < <(find . -type f -name "$ext" -print0)
done

echo "✅ Done."
