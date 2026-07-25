#!/usr/bin/env bash
set -euo pipefail

site_output_dir="$(mktemp -d)"
trap 'rm -rf -- "$site_output_dir"' EXIT

hugo --minify --baseURL "https://okrs.chat/" --destination "$site_output_dir"

assert_contains() {
  local file_path="$1"
  local expected_text="$2"
  rg --fixed-strings --quiet "$expected_text" "$file_path"
}

assert_not_contains() {
  local file_path="$1"
  local forbidden_text="$2"
  ! rg --fixed-strings --quiet "$forbidden_text" "$file_path"
}

assert_journal_metadata() {
  local content_file="$1"

  rg --quiet '^title: .+' "$content_file"
  rg --quiet '^description: .+' "$content_file"
  rg --quiet '^date: .+' "$content_file"
}

test -f "$site_output_dir/index.html"
test -f "$site_output_dir/blog/index.html"
test -f "$site_output_dir/blog/hello-world/index.html"
test -f "$site_output_dir/robots.txt"
test -f "$site_output_dir/sitemap.xml"
test -f "$site_output_dir/images/okrs-social.png"
test ! -f "$site_output_dir/CNAME"
rg --fixed-strings --quiet -- "--color-paper:" "$site_output_dir/css"

while IFS= read -r content_file; do
  assert_journal_metadata "$content_file"
done < <(find content/blog -type f -name '*.md' ! -name '_index.md' | sort)

assert_contains "$site_output_dir/index.html" "Better OKRs start with"
assert_contains "$site_output_dir/index.html" "Coming soon."
assert_contains "$site_output_dir/index.html" "Marc Gelpi, OKR expert"
assert_contains "$site_output_dir/index.html" "<title>OKRs.chat</title>"
assert_contains "$site_output_dir/index.html" "<meta name=description content=\"A Socratic space"
assert_contains "$site_output_dir/index.html" "<link rel=canonical href=https://okrs.chat/>"
assert_contains "$site_output_dir/index.html" "<meta property=\"og:url\" content=\"https://okrs.chat/\">"
assert_contains "$site_output_dir/index.html" "<meta property=\"og:image\" content=\"https://okrs.chat/images/okrs-social.png\">"
assert_contains "$site_output_dir/index.html" "<meta name=twitter:card content=\"summary_large_image\">"
assert_contains "$site_output_dir/index.html" "rel=alternate type=application/rss+xml"
assert_contains "$site_output_dir/index.html" "application/ld+json"
assert_contains "$site_output_dir/index.html" "WebSite"
assert_contains "$site_output_dir/blog/index.html" "Hello World"
assert_contains "$site_output_dir/blog/index.html" "href=/blog/hello-world/"
assert_contains "$site_output_dir/blog/index.html" "<title>Journal | OKRs.chat</title>"
assert_contains "$site_output_dir/blog/index.html" "<link rel=canonical href=https://okrs.chat/blog/>"
assert_contains "$site_output_dir/blog/index.html" "rel=alternate type=application/rss+xml"
assert_contains "$site_output_dir/blog/hello-world/index.html" "Hello World."
assert_contains "$site_output_dir/blog/hello-world/index.html" "<title>Hello World | OKRs.chat</title>"
assert_contains "$site_output_dir/blog/hello-world/index.html" "<link rel=canonical href=https://okrs.chat/blog/hello-world/>"
assert_contains "$site_output_dir/blog/hello-world/index.html" "<meta property=\"og:type\" content=\"article\">"
assert_contains "$site_output_dir/blog/hello-world/index.html" "<meta name=twitter:image content=\"https://okrs.chat/images/okrs-social.png\">"
assert_contains "$site_output_dir/blog/hello-world/index.html" "BlogPosting"
assert_contains "$site_output_dir/blog/hello-world/index.html" "Marc Gelpi, OKR expert"
assert_contains "$site_output_dir/index.xml" "https://okrs.chat/"
assert_contains "$site_output_dir/blog/index.xml" "https://okrs.chat/blog/hello-world/"
assert_contains "$site_output_dir/robots.txt" "User-agent: *"
assert_contains "$site_output_dir/robots.txt" "User-agent: Googlebot"
assert_contains "$site_output_dir/robots.txt" "User-agent: Bingbot"
assert_contains "$site_output_dir/robots.txt" "User-agent: OAI-SearchBot"
assert_contains "$site_output_dir/robots.txt" "Sitemap: https://okrs.chat/sitemap.xml"
assert_not_contains "$site_output_dir/robots.txt" "Disallow: /"

expected_article_count="$(find content/blog -type f -name '*.md' ! -name '_index.md' | wc -l | tr -d '[:space:]')"
generated_article_count="$(find "$site_output_dir/blog" -type f -name 'index.html' ! -path "$site_output_dir/blog/index.html" | wc -l | tr -d '[:space:]')"
test "$generated_article_count" -eq "$expected_article_count"

while IFS= read -r article_page; do
  relative_path="${article_page#"$site_output_dir"}"
  public_path="${relative_path%/index.html}"
  canonical_url="https://okrs.chat${public_path}/"

  assert_contains "$article_page" "<link rel=canonical href=$canonical_url>"
  assert_contains "$article_page" "<meta property=\"og:type\" content=\"article\">"
  assert_contains "$article_page" "BlogPosting"
  assert_contains "$article_page" "Marc Gelpi, OKR expert"
  assert_contains "$site_output_dir/sitemap.xml" "$canonical_url"
done < <(find "$site_output_dir/blog" -type f -name 'index.html' ! -path "$site_output_dir/blog/index.html" | sort)

expected_sitemap_count="$(find "$site_output_dir" -type f -name 'index.html' | wc -l | tr -d '[:space:]')"
generated_sitemap_count="$(rg --fixed-strings --only-matching '<loc>' "$site_output_dir/sitemap.xml" | wc -l | tr -d '[:space:]')"
test "$generated_sitemap_count" -eq "$expected_sitemap_count"
