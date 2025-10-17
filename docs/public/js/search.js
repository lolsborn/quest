// Simple client-side search for Quest documentation

(function() {
    'use strict';

    let searchIndex = [];
    let searchInput = document.getElementById('search-input');
    let searchResults = document.getElementById('search-results');

    if (!searchInput || !searchResults) {
        return; // Search elements not found
    }

    // Calculate path to search index - look for css_path pattern in page
    // For root pages: search-index.json
    // For nested pages: ../search-index.json (or ../../, etc.)
    let searchIndexPath = 'search-index.json';

    // Check if we're in a subdirectory by looking at CSS link paths
    const cssLink = document.querySelector('link[href*="css/style.css"]');
    if (cssLink) {
        const href = cssLink.getAttribute('href');
        if (href && href.startsWith('../')) {
            const match = href.match(/^(\.\.\/)+/);
            if (match) {
                searchIndexPath = match[0] + 'search-index.json';
            }
        }
    }

    // Load search index
    fetch(searchIndexPath)
        .then(response => response.json())
        .then(data => {
            searchIndex = data;
            console.log('Search index loaded:', searchIndex.length, 'documents');
        })
        .catch(error => {
            console.error('Failed to load search index from', searchIndexPath, ':', error);
        });

    // Debounce function to limit search frequency
    function debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    // Search function
    function search(query) {
        if (!query || query.length < 2) {
            searchResults.innerHTML = '';
            searchResults.style.display = 'none';
            return;
        }

        const queryLower = query.toLowerCase();
        const results = [];

        // Simple text matching - search in title and content
        for (let i = 0; i < searchIndex.length; i++) {
            const doc = searchIndex[i];
            const titleMatch = doc.title.toLowerCase().indexOf(queryLower) !== -1;
            const contentMatch = doc.content.toLowerCase().indexOf(queryLower) !== -1;

            if (titleMatch || contentMatch) {
                // Calculate relevance score (title matches are more important)
                let score = 0;
                if (titleMatch) {
                    score += 10;
                }
                if (contentMatch) {
                    score += 1;
                }

                // Extract snippet around match
                let snippet = '';
                if (contentMatch) {
                    const contentLower = doc.content.toLowerCase();
                    const matchIndex = contentLower.indexOf(queryLower);
                    const start = Math.max(0, matchIndex - 50);
                    const end = Math.min(doc.content.length, matchIndex + query.length + 50);
                    snippet = doc.content.substring(start, end).trim();
                    if (start > 0) snippet = '...' + snippet;
                    if (end < doc.content.length) snippet = snippet + '...';
                }

                results.push({
                    title: doc.title,
                    url: doc.url,
                    snippet: snippet,
                    score: score
                });
            }
        }

        // Sort by score (descending)
        results.sort((a, b) => b.score - a.score);

        // Display results (limit to 10)
        displayResults(results.slice(0, 10), query);
    }

    // Display search results
    function displayResults(results, query) {
        if (results.length === 0) {
            searchResults.innerHTML = '<div class="search-no-results">No results found</div>';
            searchResults.style.display = 'block';
            return;
        }

        let html = '';
        for (let i = 0; i < results.length; i++) {
            const result = results[i];
            const highlightedTitle = highlightMatch(result.title, query);
            const highlightedSnippet = result.snippet ? highlightMatch(result.snippet, query) : '';

            html += '<a href="' + result.url + '" class="search-result-item">';
            html += '<div class="search-result-title">' + highlightedTitle + '</div>';
            if (highlightedSnippet) {
                html += '<div class="search-result-snippet">' + highlightedSnippet + '</div>';
            }
            html += '</a>';
        }

        searchResults.innerHTML = html;
        searchResults.style.display = 'block';
    }

    // Highlight matching text
    function highlightMatch(text, query) {
        const regex = new RegExp('(' + escapeRegex(query) + ')', 'gi');
        return text.replace(regex, '<mark>$1</mark>');
    }

    // Escape special regex characters
    function escapeRegex(str) {
        return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }

    // Event listeners
    searchInput.addEventListener('input', debounce(function(e) {
        search(e.target.value);
    }, 300));

    // Close search results when clicking outside
    document.addEventListener('click', function(e) {
        if (!searchInput.contains(e.target) && !searchResults.contains(e.target)) {
            searchResults.style.display = 'none';
        }
    });

    // Show results again when focusing on input
    searchInput.addEventListener('focus', function() {
        if (searchInput.value.length >= 2 && searchResults.innerHTML) {
            searchResults.style.display = 'block';
        }
    });

    // Keyboard shortcuts
    document.addEventListener('keydown', function(e) {
        // Ctrl+K or Cmd+K to focus search
        if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
            e.preventDefault();
            searchInput.focus();
        }
        // Escape to close search results
        if (e.key === 'Escape') {
            searchResults.style.display = 'none';
            searchInput.blur();
        }
    });
})();
