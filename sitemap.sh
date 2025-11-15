#!/bin/bash

# sitemap-update.sh
# Incremental update to sitemap.xml for modified HTML files in the last commit.
# Removes old entries for modified files, adds new entries with updated lastmod, and re-sorts all entries by lastmod descending.

# If the sitemap file doesn't exist, create a new one.
if [ ! -f "sitemap.xml" ]; then
    echo "⚠️ Warning: sitemap.xml not found. Creating a new sitemap from all commits."

    cat >sitemap.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
EOF

    ( git ls-files -- '*.html' | egrep -v '(404|error|i).html' | while read file; do printf '<url><loc>https://www.plumplot.co.uk/%s</loc><lastmod>%s</lastmod></url>\n' "$file" "$(git log -1 --format="%ad" --date=format:"%Y-%m-%d" -- "$file")"; done | sort -t'<' -k5,5 |tac ) >> sitemap.xml
    echo '</urlset>' >>sitemap.xml

    temp_file=$(mktemp)
    cp sitemap.xml $temp_file
    rm -f sitemap.xml.gz
    gzip sitemap.xml
    mv $temp_file sitemap.xml

    echo "✅ New sitemap created."
    exit 0
fi


# Get modified HTML files from last commit, excluding specified patterns
modified_files=()
while IFS= read -r file; do
    if ! echo "$file" | grep -Eq '(404|error|i).html'; then
        modified_files+=("$file")
    fi
done < <(git diff --name-only HEAD~2 HEAD -- '*.html')

printf '%s\n' "${modified_files[@]}"

# If no modified files, nothing to do
if [ ${#modified_files[@]} -eq 0 ]; then
    echo "No modified HTML files to update."
    exit 0
fi

# Temporary files
temp_urls=$(mktemp)
new_urls=$(mktemp)
all_urls=$(mktemp)
sorted=$(mktemp)

# Extract existing <url> entries
grep '^<url>' sitemap.xml > "$temp_urls" || true  # If no matches, empty is fine

# Remove entries for modified files
for file in "${modified_files[@]}"; do
    loc="https://www.plumplot.co.uk/${file//\//\\/}"
    sed -i "\#<loc>$loc</loc>#d" "$temp_urls"
done

# Generate new entries for modified files
for file in "${modified_files[@]}"; do
    date=$(git log -1 --format="%ad" --date=format:"%Y-%m-%d" -- "$file")
    echo "<url><loc>https://www.plumplot.co.uk/$file</loc><lastmod>$date</lastmod></url>" >> "$new_urls"
done

# Combine old and new entries
cat "$temp_urls" "$new_urls" > "$all_urls"

# Sort by lastmod date descending (assuming structure allows -t'<' -k5,5)
sort -t'<' -k5,5 "$all_urls" | tac > "$sorted"

# Build new sitemap.xml
cat > sitemap.xml.new <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
EOF

cat "$sorted" >> sitemap.xml.new
echo '</urlset>' >> sitemap.xml.new

# Replace old sitemap
cp sitemap.xml.new sitemap.xml
rm -f sitemap.xml.gz
gzip sitemap.xml
mv sitemap.xml.new sitemap.xml

# Cleanup
rm "$temp_urls" "$new_urls" "$all_urls" "$sorted"
./aws2https.sh

echo "sitemap.xml updated successfully. Add sitemap.xml.gz and forcepush."
