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

test -f "$site_output_dir/index.html"
test -f "$site_output_dir/blog/index.html"
test -f "$site_output_dir/blog/hello-world/index.html"
test -f "$site_output_dir/robots.txt"
test -f "$site_output_dir/sitemap.xml"
test -f "$site_output_dir/images/okrs-social.png"
test ! -f "$site_output_dir/CNAME"

assert_contains "$site_output_dir/index.html" "Better OKRs start with"
assert_contains "$site_output_dir/index.html" "Coming soon."
assert_contains "$site_output_dir/index.html" "https://okrs.chat/"
assert_contains "$site_output_dir/index.html" "application/ld+json"
assert_contains "$site_output_dir/index.html" "WebSite"
assert_contains "$site_output_dir/blog/index.html" "Hello World"
assert_contains "$site_output_dir/blog/index.html" "href=\"/blog/hello-world/\""
assert_contains "$site_output_dir/blog/hello-world/index.html" "Hello World."
assert_contains "$site_output_dir/blog/hello-world/index.html" "BlogPosting"
assert_contains "$site_output_dir/blog/hello-world/index.html" "Marc Gelpi, OKR expert"
assert_contains "$site_output_dir/robots.txt" "User-agent: *"
assert_contains "$site_output_dir/robots.txt" "User-agent: Googlebot"
assert_contains "$site_output_dir/robots.txt" "User-agent: Bingbot"
assert_contains "$site_output_dir/robots.txt" "User-agent: OAI-SearchBot"
assert_contains "$site_output_dir/robots.txt" "Sitemap: https://okrs.chat/sitemap.xml"
assert_contains "$site_output_dir/sitemap.xml" "https://okrs.chat/blog/hello-world/"
