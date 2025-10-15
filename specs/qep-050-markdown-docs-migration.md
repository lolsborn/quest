# QEP-050: Markdown Documentation System & Docusaurus Migration

**Status**: Draft
**Created**: 2025-10-15
**Author**: Quest Core Team
**Related**: QEP-028 (Serve Command), QEP-001 (Database API)

## Summary

Add native markdown rendering support to Quest via `std/markdown` module (backed by `pulldown-cmark`) and migrate 48 documentation pages from Docusaurus to a Quest-native web documentation system at `/quest/*` endpoints with syntax highlighting (Prism.js), navigation, and search.

## Motivation

### Current State

Quest documentation lives in a Docusaurus site (`docs/docs/`) with:
- 48 markdown files organized into categories (Language, Types, Stdlib, Advanced)
- React-based UI with heavy JavaScript bundle
- Separate build/deploy process from Quest itself
- No integration with Quest's web server capabilities

### Problems

1. **External dependency**: Documentation requires Node.js, npm, and Docusaurus build toolchain
2. **Heavy frontend**: React adds ~200KB+ JavaScript for simple documentation browsing
3. **No dogfooding**: We don't use Quest to serve Quest documentation
4. **Disconnect**: Documentation is separate from the language's web capabilities
5. **Barrier to contribution**: Contributors need to understand Docusaurus to update docs

### Goals

1. **Native markdown support**: Add `std/markdown` module for parsing CommonMark
2. **Simple HTML/CSS**: Replace React with Tera templates and static assets
3. **Preserve features**: Keep sidebar navigation, prev/next, TOC, syntax highlighting
4. **Performance**: Serve docs directly from Quest web server (QEP-028)
5. **Developer happiness**: Make docs easy to update (just edit `.md` files)

## Proposed Changes

### 1. Add `std/markdown` Module

Add `pulldown-cmark` crate to Quest for CommonMark parsing:

```toml
# Cargo.toml
[dependencies]
pulldown-cmark = "0.11"
```

Implement new stdlib module `std/markdown`:

```quest
use "std/markdown"

# Basic parsing
let html = markdown.parse("# Hello\n\nWorld")
# → "<h1>Hello</h1>\n<p>World</p>"

# Parse with frontmatter
let result = markdown.parse_with_frontmatter("""
---
title: My Doc
position: 1
---
# Content here
""")
# → {frontmatter: {title: "My Doc", position: 1}, html: "<h1>Content here</h1>"}

# Extract table of contents
let toc = markdown.extract_headings("# Top\n## Sub\n### Deep")
# → [{level: 1, text: "Top", id: "top"}, {level: 2, text: "Sub", id: "sub"}, ...]
```

#### API Surface

```quest
# Module: std/markdown

# Parse markdown to HTML
fun parse(text: str) -> str

# Parse with YAML frontmatter
fun parse_with_frontmatter(text: str) -> dict
# Returns: {frontmatter: dict, html: str}

# Extract headings for TOC generation
fun extract_headings(text: str) -> array
# Returns: [{level: Int, text: str, id: str}, ...]

# Parse markdown to HTML with options
fun parse_with_options(text: str, options: dict) -> str
# Options: {
#   unsafe_html: bool,        # Allow raw HTML (default: false)
#   smart_punctuation: bool,  # Convert quotes, dashes (default: true)
#   github_tables: bool,      # GitHub-flavored tables (default: true)
#   strikethrough: bool,      # ~~text~~ (default: true)
#   task_lists: bool,         # - [ ] and - [x] (default: true)
# }
```

### 2. Rust Implementation

```rust
// src/modules/markdown/mod.rs
use pulldown_cmark::{Parser, Options, html, Event, Tag, HeadingLevel};
use std::collections::HashMap;

pub fn parse(text: &str) -> String {
    let mut options = Options::empty();
    options.insert(Options::ENABLE_TABLES);
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TASKLISTS);

    let parser = Parser::new_ext(text, options);
    let mut html_output = String::new();
    html::push_html(&mut html_output, parser);
    html_output
}

pub fn parse_with_frontmatter(text: &str) -> (HashMap<String, String>, String) {
    let (frontmatter, markdown) = extract_frontmatter(text);
    let html = parse(markdown);
    (frontmatter, html)
}

fn extract_frontmatter(text: &str) -> (HashMap<String, String>, &str) {
    if text.starts_with("---\n") {
        if let Some(end_idx) = text[4..].find("\n---\n") {
            let fm_text = &text[4..end_idx + 4];
            let markdown = &text[end_idx + 8..];
            let frontmatter = parse_yaml_simple(fm_text);
            return (frontmatter, markdown);
        }
    }
    (HashMap::new(), text)
}

pub fn extract_headings(text: &str) -> Vec<Heading> {
    let parser = Parser::new(text);
    let mut headings = Vec::new();
    let mut current_heading: Option<(usize, String)> = None;

    for event in parser {
        match event {
            Event::Start(Tag::Heading(level, ..)) => {
                current_heading = Some((heading_level_to_usize(level), String::new()));
            }
            Event::Text(text) => {
                if let Some((_, ref mut heading_text)) = current_heading {
                    heading_text.push_str(&text);
                }
            }
            Event::End(Tag::Heading(..)) => {
                if let Some((level, text)) = current_heading.take() {
                    headings.push(Heading {
                        level,
                        text: text.clone(),
                        id: slugify(&text),
                    });
                }
            }
            _ => {}
        }
    }

    headings
}

#[derive(Clone)]
pub struct Heading {
    pub level: usize,
    pub text: String,
    pub id: String,
}

fn slugify(text: &str) -> String {
    text.to_lowercase()
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { '-' })
        .collect::<String>()
        .split('-')
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join("-")
}
```

### 3. Documentation Structure

```
examples/web/blog/
├── index.q                          # Main request handler
├── docs_metadata.json               # Navigation structure (generated)
├── content/
│   └── quest/                       # Migrated markdown files
│       ├── introduction.md
│       ├── getting-started.md
│       ├── language/
│       │   ├── objects.md
│       │   ├── types.md
│       │   ├── variables.md
│       │   ├── control-flow.md
│       │   ├── loops.md
│       │   ├── functions.md
│       │   ├── builtins.md
│       │   ├── modules.md
│       │   └── exceptions.md
│       ├── types/
│       │   ├── number.md
│       │   ├── bigint.md
│       │   ├── bool.md
│       │   ├── nil.md
│       │   ├── string.md
│       │   ├── bytes.md
│       │   ├── array.md
│       │   └── dicts.md
│       ├── stdlib/
│       │   ├── index.md
│       │   ├── math.md
│       │   ├── str.md
│       │   ├── sys.md
│       │   ├── os.md
│       │   ├── io.md
│       │   ├── time.md
│       │   ├── encoding.md
│       │   ├── json.md
│       │   ├── urlparse.md
│       │   ├── compress.md
│       │   ├── hash.md
│       │   ├── crypto.md
│       │   ├── uuid.md
│       │   ├── rand.md
│       │   ├── database.md
│       │   ├── http.md
│       │   ├── html_templates.md
│       │   ├── serial.md
│       │   ├── test.md
│       │   ├── regex.md
│       │   ├── settings.md
│       │   ├── term.md
│       │   └── process.md
│       └── advanced/
│           └── system-variables.md
├── templates/
│   ├── base.html                    # Updated base template
│   └── quest/
│       ├── doc.html                 # Documentation page template
│       ├── sidebar.html             # Navigation sidebar
│       └── search.html              # Search modal (optional)
└── public/
    ├── style.css                    # Extended with docs styles
    ├── docs.css                     # Documentation-specific styles
    └── prism/
        ├── prism.js                 # Syntax highlighter
        ├── prism.css                # Highlighting theme
        └── prism-quest.js           # Custom Quest language definition
```

### 4. Template System

**`templates/quest/doc.html`**:
```html
{% extends "base.html" %}

{% block title %}{{ title }} | Quest Documentation{% endblock %}

{% block head %}
<link rel="stylesheet" href="/public/docs.css">
<link rel="stylesheet" href="/public/prism/prism.css">
{% endblock %}

{% block content %}
<div class="docs-layout">
  <!-- Navigation sidebar -->
  <aside class="docs-sidebar">
    <div class="sidebar-header">
      <a href="/quest" class="logo">Quest Docs</a>
    </div>
    <nav class="sidebar-nav">
      {% include "quest/sidebar.html" %}
    </nav>
  </aside>

  <!-- Main content -->
  <main class="docs-main">
    <!-- Breadcrumbs -->
    <nav class="breadcrumbs">
      <a href="/quest">Docs</a>
      {% for crumb in breadcrumbs %}
        <span class="sep">›</span>
        {% if crumb.url %}
          <a href="{{ crumb.url }}">{{ crumb.label }}</a>
        {% else %}
          <span>{{ crumb.label }}</span>
        {% endif %}
      {% endfor %}
    </nav>

    <!-- Content -->
    <article class="markdown-content">
      {{ content | safe }}
    </article>

    <!-- Pagination -->
    <nav class="doc-pagination">
      {% if prev %}
        <a href="{{ prev.url }}" class="prev">
          <span class="label">Previous</span>
          <span class="title">{{ prev.title }}</span>
        </a>
      {% endif %}
      {% if next %}
        <a href="{{ next.url }}" class="next">
          <span class="label">Next</span>
          <span class="title">{{ next.title }}</span>
        </a>
      {% endif %}
    </nav>
  </main>

  <!-- Table of contents -->
  <aside class="docs-toc">
    <h4>On This Page</h4>
    <nav class="toc-nav">
      {{ toc | safe }}
    </nav>
  </aside>
</div>

<script src="/public/prism/prism.js" data-manual></script>
<script src="/public/prism/prism-quest.js"></script>
<script>
  document.addEventListener('DOMContentLoaded', () => {
    Prism.highlightAll();
  });
</script>
{% endblock %}
```

**`templates/quest/sidebar.html`**:
```html
{% for item in sidebar %}
  {% if item.type == "category" %}
    <div class="sidebar-category">
      <button class="category-toggle {% if item.collapsed %}collapsed{% endif %}">
        <span class="icon">{% if item.collapsed %}▶{% else %}▼{% endif %}</span>
        <span class="label">{{ item.label }}</span>
      </button>
      <ul class="category-items {% if item.collapsed %}hidden{% endif %}">
        {% for child in item.items %}
          <li>
            <a href="{{ child.url }}"
               class="{% if child.active %}active{% endif %}">
              {{ child.label }}
            </a>
          </li>
        {% endfor %}
      </ul>
    </div>
  {% else %}
    <a href="{{ item.url }}"
       class="sidebar-item {% if item.active %}active{% endif %}">
      {{ item.label }}
    </a>
  {% endif %}
{% endfor %}
```

### 5. Route Handler

**Extended `index.q`**:
```quest
use "std/encoding/json"
use "std/html/templates"
use "std/db/sqlite"
use "std/markdown"
use "std/io"

# ... existing blog handlers ...

# Documentation metadata (loaded once at startup)
let docs_meta = json.parse(io.read("docs_metadata.json"))

fun handle_request(req)
    let path = req["path"]

    if path == "/"
        return home_handler(req)
    elif path.starts_with("/post/")
        return post_handler(req)
    elif path == "/quest" or path.starts_with("/quest/")
        return quest_docs_handler(req)
    elif path.starts_with("/public/")
        return static_file_handler(req)
    else
        return not_found_handler(req)
    end
end

fun quest_docs_handler(req)
    let path = req["path"]

    # Default to introduction
    if path == "/quest" or path == "/quest/"
        path = "/quest/introduction"
    end

    # Map URL to file: /quest/language/functions → content/quest/language/functions.md
    let doc_path = "content" .. path .. ".md"

    # Check if file exists
    if !io.exists(doc_path)
        return not_found_handler(req)
    end

    # Read and parse markdown
    let markdown_text = io.read(doc_path)
    let parsed = markdown.parse_with_frontmatter(markdown_text)

    # Get navigation context from metadata
    let nav_ctx = get_navigation_context(path, docs_meta)

    # Generate TOC from headings
    let headings = markdown.extract_headings(markdown_text)
    let toc_html = generate_toc_html(headings)

    # Render template
    let html = tmpl.render("quest/doc.html", {
        title: parsed["frontmatter"]["title"] or extract_title_from_html(parsed["html"]),
        content: parsed["html"],
        breadcrumbs: nav_ctx["breadcrumbs"],
        prev: nav_ctx["prev"],
        next: nav_ctx["next"],
        toc: toc_html,
        sidebar: nav_ctx["sidebar"]
    })

    return {
        status: 200,
        headers: {"Content-Type": "text/html; charset=utf-8"},
        body: html
    }
end

fun get_navigation_context(current_path, metadata)
    # Find current doc in structure
    let pages = metadata["pages"]
    let current_idx = nil

    let i = 0
    while i < pages.len()
        if pages[i]["path"] == current_path
            current_idx = i
            break
        end
        i = i + 1
    end

    if current_idx == nil
        return {breadcrumbs: [], prev: nil, next: nil, sidebar: metadata["sidebar"]}
    end

    # Build context
    let current = pages[current_idx]
    let prev = if current_idx > 0 then pages[current_idx - 1] else nil end
    let next = if current_idx < pages.len() - 1 then pages[current_idx + 1] else nil end

    return {
        breadcrumbs: current["breadcrumbs"],
        prev: prev,
        next: next,
        sidebar: mark_active_in_sidebar(metadata["sidebar"], current_path)
    }
end

fun generate_toc_html(headings)
    # Generate nested HTML list from headings
    if headings.len() == 0
        return ""
    end

    let html = "<ul>"
    let i = 0
    while i < headings.len()
        let h = headings[i]
        if h["level"] <= 3  # Only show h2 and h3 in TOC
            let indent = "  ".repeat(h["level"] - 2)
            html = html .. indent .. "<li><a href=\"#" .. h["id"] .. "\">" .. h["text"] .. "</a></li>"
        end
        i = i + 1
    end
    html = html .. "</ul>"
    html
end

fun extract_title_from_html(html)
    # Extract first h1 from HTML
    let start = html.find("<h1>")
    if start == nil
        return "Quest Documentation"
    end
    let end = html.find("</h1>", start)
    if end == nil
        return "Quest Documentation"
    end
    html.slice(start + 4, end)
end

fun mark_active_in_sidebar(sidebar, active_path)
    # Mark the active page in sidebar structure
    # (implementation details omitted)
    sidebar
end

fun static_file_handler(req)
    # Serve CSS, JS, images from public/
    let path = req["path"].replace("/public/", "")
    let file_path = "public/" .. path

    if !io.exists(file_path)
        return not_found_handler(req)
    end

    let content = io.read(file_path)
    let content_type = guess_content_type(file_path)

    return {
        status: 200,
        headers: {"Content-Type": content_type},
        body: content
    }
end

fun guess_content_type(path)
    if path.ends_with(".css")
        return "text/css"
    elif path.ends_with(".js")
        return "application/javascript"
    elif path.ends_with(".jpg") or path.ends_with(".jpeg")
        return "image/jpeg"
    elif path.ends_with(".png")
        return "image/png"
    else
        return "application/octet-stream"
    end
end
```

### 6. Documentation Metadata Generator

**`build_docs_metadata.q`**:
```quest
use "std/io"
use "std/encoding/json"
use "std/markdown"

# Parse sidebars structure (converted from sidebars.ts)
let sidebar_structure = [
    {type: "doc", id: "introduction", label: "Introduction"},
    {type: "doc", id: "getting-started", label: "Getting Started"},
    {
        type: "category",
        label: "Language Reference",
        collapsed: false,
        items: [
            "language/objects",
            "language/types",
            "language/variables",
            "language/control-flow",
            "language/loops",
            "language/functions",
            "language/builtins",
            "language/modules",
            "language/exceptions"
        ]
    },
    # ... more categories ...
]

# Scan content/quest/ directory
let pages = []
let sidebar_items = []

fun build_metadata()
    # Walk through sidebar structure
    process_sidebar_items(sidebar_structure, [], 0)

    # Generate metadata JSON
    let metadata = {
        pages: pages,
        sidebar: sidebar_items
    }

    # Write to file
    io.write("docs_metadata.json", json.stringify(metadata, {pretty: true}))
    puts("Generated docs_metadata.json with " .. pages.len().str() .. " pages")
end

fun process_sidebar_items(items, breadcrumbs, level)
    let i = 0
    while i < items.len()
        let item = items[i]

        if item["type"] == "doc"
            process_doc(item, breadcrumbs, level)
        elif item["type"] == "category"
            process_category(item, breadcrumbs, level)
        end

        i = i + 1
    end
end

fun process_doc(item, breadcrumbs, level)
    let id = item["id"]
    let label = item["label"] or extract_label_from_id(id)
    let path = "/quest/" .. id
    let file_path = "content/quest/" .. id .. ".md"

    # Read frontmatter
    if io.exists(file_path)
        let content = io.read(file_path)
        let parsed = markdown.parse_with_frontmatter(content)
        let fm = parsed["frontmatter"]

        # Add to pages list
        pages.push({
            path: path,
            file: file_path,
            title: fm["title"] or label,
            breadcrumbs: breadcrumbs.clone().push({label: label, url: path}),
            url: path
        })

        # Add to sidebar
        sidebar_items.push({
            type: "doc",
            label: label,
            url: path,
            level: level
        })
    end
end

fun process_category(item, breadcrumbs, level)
    # Add category to sidebar
    sidebar_items.push({
        type: "category",
        label: item["label"],
        collapsed: item["collapsed"] or false,
        level: level,
        items: []
    })

    # Process child items
    let new_breadcrumbs = breadcrumbs.clone().push({label: item["label"], url: nil})
    process_sidebar_items(item["items"], new_breadcrumbs, level + 1)
end

# Run the build
build_metadata()
```

### 7. Syntax Highlighting (Prism.js)

**Custom Quest language definition** (`public/prism/prism-quest.js`):
```javascript
(function (Prism) {
  Prism.languages.quest = {
    'comment': {
      pattern: /#.*/,
      greedy: true
    },
    'string': {
      pattern: /(["'])(?:\\.|(?!\1)[^\\\r\n])*\1|f(["'])(?:\\.|(?!\2)[^\\\r\n])*\2/,
      greedy: true
    },
    'number': /\b\d+(?:\.\d+)?(?:e[+-]?\d+)?n?\b|0x[a-fA-F0-9]+n?|0b[01]+n?|0o[0-7]+n?/i,
    'keyword': /\b(?:fun|end|let|const|if|elif|else|while|for|in|return|break|continue|type|trait|impl|use|as|match|try|catch|ensure|raise|with|static|pub)\b/,
    'builtin': /\b(?:puts|print|str|int|float|bool|nil|true|false|Array|Dict|Int|Float|Bool|Str|Nil)\b/,
    'function': /\b[a-zA-Z_]\w*(?=\s*\()/,
    'boolean': /\b(?:true|false)\b/,
    'nil': /\bnil\b/,
    'operator': /[+\-*\/%]=?|==|!=|<=?|>=?|&&|\|\||!|\.\.|\?/,
    'punctuation': /[{}[\](),.:]/
  };

  Prism.languages.q = Prism.languages.quest;
}(Prism));
```

### 8. CSS Styling

**`public/docs.css`**:
```css
/* Three-column layout */
.docs-layout {
  display: grid;
  grid-template-columns: 250px 1fr 200px;
  gap: 2rem;
  max-width: 1400px;
  margin: 0 auto;
  padding: 2rem;
}

/* Sidebar */
.docs-sidebar {
  position: sticky;
  top: 2rem;
  height: calc(100vh - 4rem);
  overflow-y: auto;
}

.sidebar-header {
  padding: 1rem 0;
  border-bottom: 1px solid #ddd;
  margin-bottom: 1rem;
}

.logo {
  font-size: 1.5rem;
  font-weight: bold;
  text-decoration: none;
  color: #333;
}

.sidebar-category {
  margin-bottom: 1rem;
}

.category-toggle {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem;
  background: none;
  border: none;
  cursor: pointer;
  font-weight: 600;
  color: #666;
}

.category-items {
  list-style: none;
  padding-left: 1.5rem;
}

.category-items.hidden {
  display: none;
}

.category-items a {
  display: block;
  padding: 0.4rem 0.5rem;
  color: #555;
  text-decoration: none;
  border-radius: 4px;
}

.category-items a:hover {
  background: #f5f5f5;
}

.category-items a.active {
  background: #e3f2fd;
  color: #1976d2;
  font-weight: 500;
}

/* Main content */
.docs-main {
  min-width: 0;
}

.breadcrumbs {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.9rem;
  color: #666;
  margin-bottom: 2rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid #eee;
}

.breadcrumbs .sep {
  color: #ccc;
}

.breadcrumbs a {
  color: #1976d2;
  text-decoration: none;
}

.breadcrumbs a:hover {
  text-decoration: underline;
}

/* Markdown content */
.markdown-content {
  line-height: 1.7;
  color: #333;
}

.markdown-content h1 {
  font-size: 2.5rem;
  margin-bottom: 1rem;
  border-bottom: 2px solid #eee;
  padding-bottom: 0.5rem;
}

.markdown-content h2 {
  font-size: 1.8rem;
  margin-top: 2.5rem;
  margin-bottom: 1rem;
  border-bottom: 1px solid #eee;
  padding-bottom: 0.3rem;
}

.markdown-content h3 {
  font-size: 1.4rem;
  margin-top: 2rem;
  margin-bottom: 0.8rem;
}

.markdown-content pre {
  background: #f5f5f5;
  border: 1px solid #ddd;
  border-radius: 4px;
  padding: 1rem;
  overflow-x: auto;
}

.markdown-content code {
  background: #f5f5f5;
  padding: 0.2rem 0.4rem;
  border-radius: 3px;
  font-family: 'Monaco', 'Courier New', monospace;
  font-size: 0.9em;
}

.markdown-content pre code {
  background: none;
  padding: 0;
}

.markdown-content table {
  width: 100%;
  border-collapse: collapse;
  margin: 1.5rem 0;
}

.markdown-content th,
.markdown-content td {
  padding: 0.75rem;
  border: 1px solid #ddd;
  text-align: left;
}

.markdown-content th {
  background: #f5f5f5;
  font-weight: 600;
}

.markdown-content blockquote {
  border-left: 4px solid #1976d2;
  padding-left: 1rem;
  margin: 1.5rem 0;
  color: #666;
  font-style: italic;
}

/* Pagination */
.doc-pagination {
  display: flex;
  justify-content: space-between;
  margin-top: 3rem;
  padding-top: 2rem;
  border-top: 1px solid #eee;
  gap: 1rem;
}

.doc-pagination a {
  display: flex;
  flex-direction: column;
  padding: 1rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  text-decoration: none;
  color: #333;
  flex: 1;
  max-width: 45%;
}

.doc-pagination a:hover {
  border-color: #1976d2;
  background: #f5f5f5;
}

.doc-pagination .label {
  font-size: 0.85rem;
  color: #666;
  margin-bottom: 0.3rem;
}

.doc-pagination .title {
  font-weight: 500;
  color: #1976d2;
}

.doc-pagination .next {
  text-align: right;
  margin-left: auto;
}

/* Table of contents */
.docs-toc {
  position: sticky;
  top: 2rem;
  height: calc(100vh - 4rem);
  overflow-y: auto;
  font-size: 0.9rem;
}

.docs-toc h4 {
  font-size: 0.85rem;
  text-transform: uppercase;
  color: #666;
  margin-bottom: 1rem;
}

.toc-nav ul {
  list-style: none;
  padding: 0;
}

.toc-nav a {
  display: block;
  padding: 0.3rem 0;
  color: #666;
  text-decoration: none;
  border-left: 2px solid transparent;
  padding-left: 0.75rem;
}

.toc-nav a:hover {
  color: #1976d2;
  border-left-color: #1976d2;
}

/* Responsive */
@media (max-width: 1200px) {
  .docs-layout {
    grid-template-columns: 250px 1fr;
  }
  .docs-toc {
    display: none;
  }
}

@media (max-width: 768px) {
  .docs-layout {
    grid-template-columns: 1fr;
  }
  .docs-sidebar {
    position: static;
    height: auto;
    margin-bottom: 2rem;
  }
}
```

## Implementation Plan

### Phase 1: Core Markdown Support (2-3 days)
1. Add `pulldown-cmark` to Cargo.toml
2. Implement `src/modules/markdown/mod.rs`
3. Add Quest module registration in `src/modules/mod.rs`
4. Write tests for markdown parsing, frontmatter, heading extraction
5. Update documentation (stdlib/markdown.md)

### Phase 2: Migration Infrastructure (1-2 days)
6. Copy markdown files from `docs/docs/` to `examples/web/blog/content/quest/`
7. Create `build_docs_metadata.q` script
8. Convert `sidebars.ts` structure to Quest-compatible format
9. Generate initial `docs_metadata.json`
10. Validate all files parse correctly

### Phase 3: Web Integration (2-3 days)
11. Create documentation templates (doc.html, sidebar.html)
12. Write CSS for documentation layout (docs.css)
13. Implement `quest_docs_handler()` in index.q
14. Add navigation context logic
15. Test routing for all 48 pages

### Phase 4: Syntax Highlighting (1 day)
16. Download Prism.js core + autoloader
17. Write custom Quest language definition
18. Integrate Prism into templates
19. Test code highlighting across languages

### Phase 5: Polish & Testing (1-2 days)
20. Verify all internal links work
21. Test prev/next navigation
22. Ensure mobile responsiveness
23. Add search functionality (optional)
24. Performance testing and optimization

**Total Estimated Time**: 7-11 days

## Testing Strategy

### Unit Tests
- Markdown parsing edge cases
- Frontmatter extraction (valid/invalid YAML)
- Heading extraction for TOC
- HTML sanitization (XSS prevention)

### Integration Tests
- All 48 docs pages load successfully
- Navigation links are correct
- Prev/next pagination works
- Breadcrumbs match hierarchy
- TOC matches document structure

### Manual Testing
- Visual inspection of all pages
- Code syntax highlighting accuracy
- Mobile/tablet responsiveness
- Browser compatibility (Chrome, Firefox, Safari)

## Security Considerations

1. **XSS Prevention**: Sanitize HTML output from markdown (disable raw HTML by default)
2. **Path Traversal**: Validate file paths don't escape `content/quest/` directory
3. **DoS**: Limit markdown file size (e.g., 1MB max)
4. **Content Security Policy**: Add CSP headers for docs pages

## Performance Considerations

- **Caching**: Cache parsed markdown in production (reload on file change)
- **Pre-rendering**: Optional build step to pre-render all docs to HTML files
- **Lazy loading**: Load Prism.js only on docs pages (not blog)
- **Minification**: Minify CSS/JS for production

## Migration Checklist

- [ ] Add `pulldown-cmark` dependency
- [ ] Implement `std/markdown` module
- [ ] Copy 48 markdown files to `content/quest/`
- [ ] Create documentation templates
- [ ] Write `build_docs_metadata.q` script
- [ ] Generate `docs_metadata.json`
- [ ] Implement `quest_docs_handler()` route
- [ ] Add navigation context logic
- [ ] Download and integrate Prism.js
- [ ] Write custom Quest language definition
- [ ] Create `docs.css` stylesheet
- [ ] Test all 48 pages load correctly
- [ ] Verify internal links and navigation
- [ ] Test code syntax highlighting
- [ ] Ensure mobile responsiveness
- [ ] Add search functionality (optional)
- [ ] Write documentation for the new system
- [ ] Update CLAUDE.md with new docs location

## Backwards Compatibility

- Keep Docusaurus site until Quest docs are fully migrated and tested
- Maintain same URL structure where possible (`/docs/language/functions` → `/quest/language/functions`)
- Set up redirects from old Docusaurus URLs (if deployed publicly)

## Future Enhancements

1. **Search**: Client-side search with Fuse.js or server-side search with SQLite FTS5
2. **Versioning**: Support multiple documentation versions (v1, v2, latest)
3. **Dark mode**: Toggle between light/dark themes
4. **Edit on GitHub**: Link to edit markdown files in repo
5. **API reference**: Auto-generate docs from Rust source code
6. **Examples playground**: Interactive Quest REPL for code examples
7. **PDF export**: Generate PDF version of docs
8. **Analytics**: Track most-viewed pages to prioritize improvements

## Success Metrics

- ✅ All 48 documentation pages render correctly
- ✅ Load time < 200ms per page (cached)
- ✅ No external dependencies (Node.js, npm, React)
- ✅ Mobile-friendly (responsive design)
- ✅ Code examples highlighted correctly
- ✅ Navigation preserves Docusaurus UX
- ✅ Contributors can update docs by editing .md files

## Open Questions

1. Should we cache parsed markdown in memory or re-parse on each request?
2. Do we need versioned docs (e.g., `/quest/v1.0/`, `/quest/latest/`)?
3. Should search be client-side (Fuse.js) or server-side (SQLite FTS)?
4. Do we want dark mode support from day one?
5. Should we pre-render docs to static HTML for performance?

## References

- [pulldown-cmark documentation](https://docs.rs/pulldown-cmark/)
- [CommonMark Spec](https://spec.commonmark.org/)
- [Prism.js documentation](https://prismjs.com/)
- [Tera template engine](https://tera.netlify.app/)
- QEP-028: Serve Command (web server foundation)
- QEP-001: Database API (SQLite integration pattern)
