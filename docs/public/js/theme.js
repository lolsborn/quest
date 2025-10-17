// Theme switcher and sidebar collapse functionality

(function() {
    'use strict';

    // Theme Toggle
    const themeToggle = document.getElementById('theme-toggle');
    const themeIcon = document.querySelector('.theme-icon');
    const body = document.body;

    // Get Prism theme stylesheets
    const lightPrism = document.querySelector('link[href*="prism.css"][data-theme="light"]');
    const darkPrism = document.querySelector('link[href*="prism-okaidia.css"][data-theme="dark"]');

    // Load saved theme preference
    const savedTheme = localStorage.getItem('theme') || 'light';
    if (savedTheme === 'dark') {
        body.classList.add('dark-theme');
        if (themeIcon) themeIcon.textContent = '☀️';
        if (lightPrism) lightPrism.disabled = true;
        if (darkPrism) darkPrism.disabled = false;
    }

    // Theme toggle handler
    if (themeToggle) {
        themeToggle.addEventListener('click', function() {
            body.classList.toggle('dark-theme');
            const isDark = body.classList.contains('dark-theme');

            // Update icon
            if (themeIcon) {
                themeIcon.textContent = isDark ? '☀️' : '🌙';
            }

            // Switch Prism theme
            if (isDark) {
                if (lightPrism) lightPrism.disabled = true;
                if (darkPrism) darkPrism.disabled = false;
            } else {
                if (lightPrism) lightPrism.disabled = false;
                if (darkPrism) darkPrism.disabled = true;
            }

            // Force Prism to re-highlight
            if (window.Prism) {
                Prism.highlightAll();
            }

            // Save preference
            localStorage.setItem('theme', isDark ? 'dark' : 'light');
        });
    }

    // Collapsible Sidebar Categories
    const categoryToggles = document.querySelectorAll('.category-toggle');

    categoryToggles.forEach(function(toggle) {
        const categoryLi = toggle.parentElement;

        // On page load: if this section contains the active page, expand it
        const categoryItems = categoryLi.querySelector('.category-items');
        if (categoryItems && categoryItems.querySelector('a.active')) {
            categoryLi.removeAttribute('data-collapsed');
            toggle.setAttribute('aria-expanded', 'true');
        }

        // Add click handler - simple toggle
        toggle.addEventListener('click', function(e) {
            e.preventDefault();

            const isCollapsed = categoryLi.getAttribute('data-collapsed') === 'true';

            if (isCollapsed) {
                // Expand
                categoryLi.removeAttribute('data-collapsed');
                toggle.setAttribute('aria-expanded', 'true');
            } else {
                // Collapse
                categoryLi.setAttribute('data-collapsed', 'true');
                toggle.setAttribute('aria-expanded', 'false');
            }
        });
    });
})();
