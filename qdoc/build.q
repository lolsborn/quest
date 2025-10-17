#!/usr/bin/env quest
# Static site generator for Quest documentation
# Standalone system with no dependencies on Docusaurus

use "std/io" as io
use "std/os" as os
use "std/markdown" as markdown
use "std/encoding/json" as json
use "qdoc/sidebar" as sidebar_mod

# Load sidebar configuration
let sidebar = sidebar_mod.get_sidebar()

# Parse frontmatter from markdown
fun parse_frontmatter(content)
    let lines = content.split("\n")
    let in_frontmatter = false
    let frontmatter = {}
    let content_lines = []
    let i = 0

    while i < lines.len()
        let line = lines[i]

        if i == 0 and line.trim() == "---"
            in_frontmatter = true
            i = i + 1
            continue
        end

        if in_frontmatter
            if line.trim() == "---"
                in_frontmatter = false
                i = i + 1
                continue
            end

            # Simple key: value parsing
            if line.contains(":")
                let parts = line.split(":")
                let key = parts[0].trim()
                let value = parts[1].trim()
                frontmatter[key] = value
            end
            i = i + 1
            continue
        end

        content_lines.push(line)
        i = i + 1
    end

    return {
        "frontmatter": frontmatter,
        "content": content_lines.join("\n")
    }
end

fun render_sidebar_html(sidebar, current_id, base_path)
    let items = []
    let in_category = false
    let category_count = 0

    let i = 0
    while i < sidebar.len()
        let item = sidebar[i]

        if item["type"] == "category"
            # Close previous category if open
            if in_category
                items.push("    </ul>")
                items.push("  </li>")
            end

            category_count = category_count + 1
            let cat_id = item["label"].replace(" ", "-").lower()

            # First category is expanded, rest are collapsed by default
            let expanded = "false"
            let collapsed_attr = " data-collapsed=\"true\""
            if category_count == 1
                expanded = "true"
                collapsed_attr = ""
            end

            items.push("  <li class=\"sidebar-category\" data-category=\"" .. cat_id .. "\"" .. collapsed_attr .. ">")
            items.push("    <button class=\"category-toggle\" aria-expanded=\"" .. expanded .. "\">")
            items.push("      <span class=\"toggle-icon\">▼</span>")
            items.push("      <span>" .. item["label"] .. "</span>")
            items.push("    </button>")
            items.push("    <ul class=\"category-items\">")
            in_category = true
        elif item["type"] == "subcategory"
            items.push("      <li class=\"sidebar-subcategory\">" .. item["label"] .. "</li>")
        else
            let active = ""
            if item["id"] == current_id
                active = " class=\"active\""
            end
            items.push("      <li><a href=\"" .. base_path .. item["id"] .. ".html\"" .. active .. ">" .. item["label"] .. "</a></li>")
        end

        i = i + 1
    end

    # Close last category if open
    if in_category
        items.push("    </ul>")
        items.push("  </li>")
    end

    # Load and render sidebar template
    let template = io.read("qdoc/templates/sidebar.html")
    return template.replace("{{base_path}}", base_path)
                   .replace("{{items}}", items.join("\n"))
end

fun render_doc(title, content, sidebar_html, css_path, edit_url)
    let template = io.read("qdoc/templates/doc.html")
    return template.replace("{{title}}", title)
                   .replace("{{content}}", content)
                   .replace("{{sidebar}}", sidebar_html)
                   .replace("{{css_path}}", css_path)
                   .replace("{{edit_url}}", edit_url)
end

fun render_index_redirect()
    let template = io.read("qdoc/templates/redirect.html")
    return template.replace("{{url}}", "introduction.html")
                   .replace("{{title}}", "Quest Documentation")
end

# Main build function
fun build()
    puts("Building Quest documentation site...")
    puts("Reading from qdoc/docs/")

    # Find all markdown files in qdoc/docs/
    let md_files = io.glob("qdoc/docs/**/*.md")
    let docs = []

    let i = 0
    while i < md_files.len()
        let file_path = md_files[i]

        # Extract doc ID from path (relative to qdoc/docs/)
        let relative_path = file_path.slice(10, file_path.len())  # Remove "qdoc/docs/"
        let doc_id = relative_path.slice(0, relative_path.len() - 3)  # Remove .md

        puts("Processing: " .. doc_id)

        # Read and parse markdown content
        let content = io.read(file_path)
        let parsed = parse_frontmatter(content)

        # Extract title from first # heading or use doc_id
        let lines = parsed["content"].split("\n")
        let title = doc_id
        let j = 0
        while j < lines.len()
            if lines[j].starts_with("# ")
                title = lines[j].slice(2, lines[j].len()).trim()
                break
            end
            j = j + 1
        end

        # Convert to HTML using proper markdown parser
        let html_content = markdown.to_html(parsed["content"])

        # Calculate paths based on nesting level
        let path_parts = doc_id.split("/")
        let css_path = ""
        let base_path = ""
        if path_parts.len() > 1
            # Nested file - use ../
            css_path = "../"
            base_path = "../"
        end

        # Render sidebar for this page
        let sidebar_html = render_sidebar_html(sidebar, doc_id, base_path)

        # Generate GitHub edit URL
        let github_base = "https://github.com/lolsborn/quest/blob/main/qdoc/docs/"
        let edit_url = github_base .. doc_id .. ".md"

        # Render with template
        let html = render_doc(title, html_content, sidebar_html, css_path, edit_url)

        # Write output file
        let output_file = "qdoc/output/" .. doc_id .. ".html"

        # Create subdirectories if needed
        if path_parts.len() > 1
            let dir_path = "qdoc/output/" .. path_parts[0]
            if not io.exists(dir_path)
                os.mkdir(dir_path)
            end
        end

        io.write(output_file, html)

        # Track for search index
        # Extract plain text content for search (remove markdown formatting)
        let search_content = parsed["content"]
            .replace("#", "")
            .replace("*", "")
            .replace("`", "")
            .replace("[", "")
            .replace("]", "")
            .replace("(", "")
            .replace(")", "")

        docs.push({
            "title": title,
            "url": doc_id .. ".html",
            "id": doc_id,
            "content": search_content
        })

        i = i + 1
    end

    # Generate index - redirect to introduction
    let index_html = render_index_redirect()
    io.write("qdoc/output/index.html", index_html)

    # Copy static assets
    puts("Copying static assets...")

    # Create directories if they don't exist
    if not io.exists("qdoc/output/css")
        os.mkdir("qdoc/output/css")
    end
    if not io.exists("qdoc/output/js")
        os.mkdir("qdoc/output/js")
    end

    let css_files = io.glob("qdoc/public/css/*.css")
    let k = 0
    while k < css_files.len()
        let filename = css_files[k].split("/").last()
        let content = io.read(css_files[k])
        io.write("qdoc/output/css/" .. filename, content)
        k = k + 1
    end

    let js_files = io.glob("qdoc/public/js/*.js")
    let m = 0
    while m < js_files.len()
        let filename = js_files[m].split("/").last()
        let content = io.read(js_files[m])
        io.write("qdoc/output/js/" .. filename, content)
        m = m + 1
    end

    # Generate search index
    let search_index_json = json.stringify(docs)
    io.write("qdoc/output/search-index.json", search_index_json)

    puts("✓ Built " .. docs.len().str() .. " documentation pages")
    puts("✓ Generated search index")
    puts("✓ Output: qdoc/output/")
end

# Watch mode - rebuild on file changes
fun watch()
    use "std/sys" as sys
    use "std/time" as time

    puts("👁️  Watching for changes...")
    puts("Press Ctrl+C to stop")
    puts("")

    # Track last modified times
    let file_times = {}

    # Get all files to watch
    let watch_patterns = [
        "qdoc/docs/**/*.md",
        "qdoc/templates/*.html",
        "qdoc/public/css/*.css",
        "qdoc/public/js/*.js",
        "qdoc/sidebar.q"
    ]

    while true
        let changed = false
        let checked_files = 0

        # Check all patterns
        let i = 0
        while i < watch_patterns.len()
            let pattern = watch_patterns[i]
            let files = io.glob(pattern)

            let j = 0
            while j < files.len()
                let file = files[j]

                # Get modification time (we'll use file content hash as proxy)
                let content = io.read(file)
                let preview_len = 100
                if content.len() < preview_len
                    preview_len = content.len()
                end
                let current_hash = content.len().str() .. ":" .. content.slice(0, preview_len)

                if not file_times.contains(file)
                    file_times[file] = current_hash
                elif file_times[file] != current_hash
                    puts("📝 Changed: " .. file)
                    file_times[file] = current_hash
                    changed = true
                end

                checked_files = checked_files + 1
                j = j + 1
            end

            i = i + 1
        end

        # Debug: Show file count every 10 seconds
        # puts("Checked " .. checked_files.str() .. " files")

        # Rebuild if any file changed
        if changed
            puts("")
            puts("🔨 Rebuilding...")
            let start = time.ticks_ms()
            build()
            let elapsed = time.ticks_ms() - start
            puts("✓ Done in " .. elapsed.str() .. "ms")
            puts("")
            puts("👁️  Watching for changes...")
        end

        # Sleep for 1 second
        time.sleep(1)
    end
end

# Parse command-line arguments
use "std/sys" as sys

if sys.argc > 1 and (sys.argv[1] == "--watch" or sys.argv[1] == "-w")
    # Initial build
    build()
    puts("")
    # Start watch mode
    watch()
else
    # Single build
    build()
end
