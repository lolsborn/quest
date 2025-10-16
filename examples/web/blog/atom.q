# Atom 1.0 Feed Generator Module
# Provides functions to generate RFC 4287 compliant Atom feeds

use "std/time" as time

# Escape XML special characters
pub fun xml_escape(text)
    if text == nil
        return ""
    end

    let result = text.str()
    result = result.replace("&", "&amp;")
    result = result.replace("<", "&lt;")
    result = result.replace(">", "&gt;")
    result = result.replace("\"", "&quot;")
    result = result.replace("'", "&apos;")
    return result
end

# Format datetime to RFC 3339 format (required by Atom)
# Example: "2025-10-16T00:00:00Z"
pub fun format_rfc3339(datetime_str)
    # Parse the datetime string (format: "YYYY-MM-DD HH:MM:SS")
    let parts = datetime_str.split(" ")
    let date_part = parts[0]
    let time_part = "00:00:00"
    if parts.len() > 1
        time_part = parts[1]
    end

    # RFC 3339 format: YYYY-MM-DDTHH:MM:SSZ
    return date_part .. "T" .. time_part .. "Z"
end

# Generate Atom 1.0 XML feed
# Parameters:
#   feed_info: {title, link, id, subtitle, author_name, author_email (optional)}
#   entries: Array of {title, link, id, summary, published, updated (optional), tags (optional)}
pub fun generate_atom(feed_info, entries)
    let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" .. "\n"
    xml = xml .. "<feed xmlns=\"http://www.w3.org/2005/Atom\">" .. "\n"

    # Feed metadata
    xml = xml .. "  <title>" .. xml_escape(feed_info["title"]) .. "</title>" .. "\n"
    xml = xml .. "  <link href=\"" .. xml_escape(feed_info["link"]) .. "\" rel=\"alternate\"/>" .. "\n"
    xml = xml .. "  <link href=\"" .. xml_escape(feed_info["link"] .. "atom.xml") .. "\" rel=\"self\"/>" .. "\n"
    xml = xml .. "  <id>" .. xml_escape(feed_info["id"]) .. "</id>" .. "\n"

    if feed_info["subtitle"] != nil
        xml = xml .. "  <subtitle>" .. xml_escape(feed_info["subtitle"]) .. "</subtitle>" .. "\n"
    end

    # Updated timestamp (use current time or most recent entry)
    let updated = nil
    if entries.len() > 0 and entries[0]["updated"] != nil
        updated = format_rfc3339(entries[0]["updated"])
    elif entries.len() > 0 and entries[0]["published"] != nil
        updated = format_rfc3339(entries[0]["published"])
    else
        let now = time.now()
        let today = now.date()
        let year = today.year()
        let month = today.month()
        let day = today.day()
        updated = year.str() .. "-" .. month.str().pad_left(2, "0") .. "-" .. day.str().pad_left(2, "0") .. "T00:00:00Z"
    end
    xml = xml .. "  <updated>" .. updated .. "</updated>" .. "\n"

    # Author
    xml = xml .. "  <author>" .. "\n"
    xml = xml .. "    <name>" .. xml_escape(feed_info["author_name"]) .. "</name>" .. "\n"
    if feed_info["author_email"] != nil
        xml = xml .. "    <email>" .. xml_escape(feed_info["author_email"]) .. "</email>" .. "\n"
    end
    xml = xml .. "  </author>" .. "\n"

    # Add entries (posts)
    let i = 0
    while i < entries.len()
        let entry = entries[i]
        xml = xml .. "  <entry>" .. "\n"
        xml = xml .. "    <title>" .. xml_escape(entry["title"]) .. "</title>" .. "\n"
        xml = xml .. "    <link href=\"" .. xml_escape(entry["link"]) .. "\" rel=\"alternate\"/>" .. "\n"
        xml = xml .. "    <id>" .. xml_escape(entry["id"]) .. "</id>" .. "\n"
        xml = xml .. "    <published>" .. format_rfc3339(entry["published"]) .. "</published>" .. "\n"

        # Updated defaults to published if not provided
        let entry_updated = entry["published"]
        if entry["updated"] != nil
            entry_updated = entry["updated"]
        end
        xml = xml .. "    <updated>" .. format_rfc3339(entry_updated) .. "</updated>" .. "\n"

        xml = xml .. "    <summary>" .. xml_escape(entry["summary"]) .. "</summary>" .. "\n"

        # Add categories (tags)
        if entry["tags"] != nil
            let j = 0
            while j < entry["tags"].len()
                xml = xml .. "    <category term=\"" .. xml_escape(entry["tags"][j]["name"]) .. "\"/>" .. "\n"
                j = j + 1
            end
        end

        xml = xml .. "  </entry>" .. "\n"
        i = i + 1
    end

    xml = xml .. "</feed>" .. "\n"

    return xml
end
