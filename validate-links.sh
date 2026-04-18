#!/bin/bash

# Validate all external links to qubittool.com in quiz HTML files
# against the main site's sitemaps.

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

MAIN_REPO="$(cd "$(dirname "$0")/.." && pwd)"
QUIZ_DIR="$(cd "$(dirname "$0")" && pwd)"

HTML_FILES=(
  "$QUIZ_DIR/index.html"
  "$QUIZ_DIR/sbti.html"
  "$QUIZ_DIR/personality16.html"
  "$QUIZ_DIR/mental-age.html"
  "$QUIZ_DIR/humanity.html"
  "$QUIZ_DIR/workplace-animal.html"
)

SITEMAP_FILES=(
  "$MAIN_REPO/public/sitemap-tools-en.xml"
  "$MAIN_REPO/public/sitemap-blog-en.xml"
  "$MAIN_REPO/public/sitemap-glossary-en.xml"
  "$MAIN_REPO/public/sitemap-pages-en.xml"
  "$MAIN_REPO/public/sitemap-quiz-en.xml"
  "$MAIN_REPO/public/sitemap-tools-zh.xml"
  "$MAIN_REPO/public/sitemap-blog-zh.xml"
  "$MAIN_REPO/public/sitemap-glossary-zh.xml"
  "$MAIN_REPO/public/sitemap-pages-zh.xml"
  "$MAIN_REPO/public/sitemap-quiz-zh.xml"
)

# Build lookup table of valid paths from sitemaps
declare -A VALID_PATHS

for sitemap in "${SITEMAP_FILES[@]}"; do
  if [[ ! -f "$sitemap" ]]; then
    echo -e "${YELLOW}Warning: sitemap not found: $sitemap${NC}"
    continue
  fi
  while IFS= read -r url; do
    path="${url#https://qubittool.com}"
    if [[ -n "$path" ]]; then
      VALID_PATHS["$path"]=1
    fi
  done < <(grep -oE '<loc>https://qubittool\.com[^<]+' "$sitemap" | sed 's/<loc>//')
done

TOTAL=0
VALID=0
INVALID=0
INVALID_DETAILS=()

for html_file in "${HTML_FILES[@]}"; do
  if [[ ! -f "$html_file" ]]; then
    echo -e "${YELLOW}Warning: HTML file not found: $html_file${NC}"
    continue
  fi

  filename="$(basename "$html_file")"

  while IFS=: read -r line_num url; do
    TOTAL=$((TOTAL + 1))

    # Normalize: strip the domain prefix
    path="${url#https://qubittool.com}"

    # Check direct path match
    if [[ -n "${VALID_PATHS[$path]+_}" ]]; then
      VALID=$((VALID + 1))
      continue
    fi

    # Try stripping /en/ prefix
    en_path="${path#/en}"
    if [[ "$en_path" != "$path" && -n "${VALID_PATHS[$en_path]+_}" ]]; then
      VALID=$((VALID + 1))
      continue
    fi

    # Try stripping /zh/ prefix
    zh_path="${path#/zh}"
    if [[ "$zh_path" != "$path" && -n "${VALID_PATHS[$zh_path]+_}" ]]; then
      VALID=$((VALID + 1))
      continue
    fi

    # Invalid link
    INVALID=$((INVALID + 1))
    INVALID_DETAILS+=("  ${RED}✗${NC} $filename:$line_num → $url")
  done < <(grep -noE 'https://qubittool\.com[^"'"'"'"'"'"' <>)]+' "$html_file")
done

echo ""
echo "========================================="
echo "  Quiz Link Validation Report"
echo "========================================="
echo ""
echo "Total links checked: $TOTAL"
echo -e "${GREEN}Valid links: $VALID${NC}"

if [[ $INVALID -gt 0 ]]; then
  echo -e "${RED}Invalid links: $INVALID${NC}"
  echo ""
  echo "Invalid link details:"
  for detail in "${INVALID_DETAILS[@]}"; do
    echo -e "$detail"
  done
  echo ""
  exit 1
else
  echo -e "${GREEN}All links are valid!${NC}"
  echo ""
  exit 0
fi
