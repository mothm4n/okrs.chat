# Writing Journal articles

Journal entries use Markdown first and semantic HTML only where Markdown does not
provide an equivalent element. The article template supplies the only `h1`: do not
write another `# Heading` in the body of an entry.

## Structure

- Start with a plain paragraph. It becomes the lead and should explain the change
  or question the article explores.
- Use `##` for major sections, then `###` through `######` only when the argument
  truly needs more depth. Do not skip heading levels.
- Use paragraphs for prose, lists for parallel ideas, and block quotes only for
  text that benefits from separation or attribution.

## Common Markdown

- Use descriptive links: `[the OKR guide](https://example.com)`, never “click here”.
- Use `**strong**` for importance and `*emphasis*` sparingly inside body copy.
- Use fenced code blocks for examples, and tables only for genuinely tabular
  comparisons. Keep tables narrow enough to remain understandable on a phone.
- Add useful alt text to every image. Use a caption when the image needs context.

## Semantic HTML

The published content is reviewed in this repository, so standard semantic HTML is
available for elements Markdown cannot express. Use it narrowly and accessibly:

- `<details><summary>Question</summary>…</details>` for optional supporting detail.
- `<mark>` for a short highlight, `<abbr title="…">` for an abbreviation, and
  `<kbd>` for a keyboard shortcut.
- `<figure>`, `<figcaption>`, `<cite>`, `<sub>`, `<sup>`, `<samp>`, and `<var>` when
  those semantics add meaning.
- Give every `iframe` a descriptive `title`; do not embed untrusted or irrelevant
  third-party content.

Avoid layout wrappers, inline styles, scripts, fake browser chrome, and decorative
HTML. The article stylesheet owns presentation.
