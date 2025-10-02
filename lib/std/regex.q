"""
Regular expression module for Quest.

Provides pattern matching and text manipulation using regular expressions.

Available functions:
- regex.match(pattern, text) - Check if text matches pattern (returns bool)
- regex.find(pattern, text) - Find first match (returns string or nil)
- regex.find_all(pattern, text) - Find all matches (returns array)
- regex.captures(pattern, text) - Get capture groups from first match (returns array or nil)
- regex.captures_all(pattern, text) - Get all capture groups (returns array of arrays)
- regex.replace(pattern, text, replacement) - Replace first match
- regex.replace_all(pattern, text, replacement) - Replace all matches
- regex.split(pattern, text) - Split text by pattern (returns array)
- regex.is_valid(pattern) - Check if pattern is valid (returns bool)
"""
