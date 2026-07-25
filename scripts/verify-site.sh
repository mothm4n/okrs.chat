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

assert_png() {
  local file_path="$1"

  python3 - "$file_path" <<'PYTHON'
import struct
import sys
import zlib

with open(sys.argv[1], "rb") as image_file:
    image = image_file.read()

if image[:8] != b"\x89PNG\r\n\x1a\n":
    raise ValueError("missing PNG signature")

offset = 8
idat = bytearray()
header = None
has_palette = False
has_idat = False
has_end = False

while offset < len(image):
    if offset + 12 > len(image):
        raise ValueError("truncated PNG chunk")

    length = struct.unpack(">I", image[offset : offset + 4])[0]
    chunk_type = image[offset + 4 : offset + 8]
    chunk_start = offset + 8
    chunk_end = chunk_start + length
    if chunk_end + 4 > len(image):
        raise ValueError("truncated PNG data")

    chunk_data = image[chunk_start:chunk_end]
    chunk_crc = struct.unpack(">I", image[chunk_end : chunk_end + 4])[0]
    if zlib.crc32(chunk_type + chunk_data) & 0xFFFFFFFF != chunk_crc:
        raise ValueError("invalid PNG checksum")

    if chunk_type == b"IHDR":
        if header is not None or offset != 8 or length != 13:
            raise ValueError("invalid PNG header")
        width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
            ">IIBBBBB", chunk_data
        )
        allowed_bit_depths = {
            0: (1, 2, 4, 8, 16),
            2: (8, 16),
            3: (1, 2, 4, 8),
            4: (8, 16),
            6: (8, 16),
        }
        if (
            not width
            or not height
            or bit_depth not in allowed_bit_depths.get(color_type, ())
            or compression != 0
            or filtering != 0
            or interlace != 0
        ):
            raise ValueError("unsupported PNG header")
        header = width, height, bit_depth, color_type
    elif chunk_type == b"PLTE":
        if header is None or has_idat or has_palette or not 3 <= length <= 768 or length % 3:
            raise ValueError("invalid PNG palette")
        has_palette = True
    elif chunk_type == b"IDAT":
        if header is None or (header[3] == 3 and not has_palette):
            raise ValueError("invalid PNG image data")
        has_idat = True
        idat.extend(chunk_data)
    elif chunk_type == b"IEND":
        if length != 0 or has_end or chunk_end + 4 != len(image):
            raise ValueError("invalid PNG end")
        has_end = True
        break

    offset = chunk_end + 4

if header is None or not has_idat or not idat or not has_end:
    raise ValueError("incomplete PNG")

width, height, bit_depth, color_type = header
channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
bytes_per_row = (width * channels * bit_depth + 7) // 8
pixel_data = zlib.decompress(idat)
if len(pixel_data) != height * (bytes_per_row + 1):
    raise ValueError("invalid PNG pixel data")
if any(pixel_data[row * (bytes_per_row + 1)] > 4 for row in range(height)):
    raise ValueError("invalid PNG filter")
PYTHON
}

assert_required_metadata() {
  local front_matter="$1"

  printf '%s\n' "$front_matter" | rg --pcre2 --quiet '^title:\s*"(?=[^"\\]*[^"\\\s])[^"\\]+"\s*$'
  printf '%s\n' "$front_matter" | rg --pcre2 --quiet '^description:\s*"(?=[^"\\]*[^"\\\s])[^"\\]+"\s*$'
  printf '%s\n' "$front_matter" | rg --pcre2 --quiet '^date:\s*"?\d{4}-\d{2}-\d{2}"?\s*$'
}

assert_journal_metadata() {
  local content_file="$1"
  local front_matter

  front_matter="$(awk '
    NR == 1 {
      if ($0 != "---") exit 1
      next
    }
    $0 == "---" {
      found_end = 1
      exit
    }
    { print }
    END {
      if (!found_end) exit 1
    }
  ' "$content_file")"

  assert_required_metadata "$front_matter"
}

test -f "$site_output_dir/index.html"
test -f "$site_output_dir/blog/index.html"
test -f "$site_output_dir/blog/hello-world/index.html"
test -f "$site_output_dir/robots.txt"
test -f "$site_output_dir/sitemap.xml"
test -f "$site_output_dir/images/okrs-social.png"
assert_png "$site_output_dir/images/okrs-social.png"
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
  assert_contains "$site_output_dir/blog/index.html" "href=$public_path/"
  assert_contains "$site_output_dir/sitemap.xml" "$canonical_url"
done < <(find "$site_output_dir/blog" -type f -name 'index.html' ! -path "$site_output_dir/blog/index.html" | sort)

expected_sitemap_count="$(find "$site_output_dir" -type f -name 'index.html' | wc -l | tr -d '[:space:]')"
generated_sitemap_count="$(rg --fixed-strings --only-matching '<loc>' "$site_output_dir/sitemap.xml" | wc -l | tr -d '[:space:]')"
test "$generated_sitemap_count" -eq "$expected_sitemap_count"
