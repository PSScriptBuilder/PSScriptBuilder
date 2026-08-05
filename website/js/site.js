// PSScriptBuilder - site.js
// Site-wide UI interactions: theme toggle, language persistence, smooth scroll, back-to-top, copy buttons, navbar

(function () {
    const toggle = document.getElementById('themeToggle');
    const icon = toggle.querySelector('i');
    const html = document.documentElement;

    const PRISM_LIGHT = 'https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism.min.css';
    const PRISM_DARK  = 'https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css';

    function applyPrismTheme(dark) {
        var el = document.getElementById('prism-theme');
        if (el) { el.href = dark ? PRISM_DARK : PRISM_LIGHT; }
    }

    // Apply saved theme on load
    const saved = localStorage.getItem('theme') || 'light';
    html.dataset.theme = saved;
    icon.className = saved === 'dark' ? 'bi bi-sun-fill' : 'bi bi-moon-fill';
    applyPrismTheme(saved === 'dark');

    toggle.addEventListener('click', function () {
        const isDark = html.dataset.theme === 'dark';
        html.dataset.theme = isDark ? 'light' : 'dark';
        icon.className = isDark ? 'bi bi-moon-fill' : 'bi bi-sun-fill';
        localStorage.setItem('theme', html.dataset.theme);
        applyPrismTheme(!isDark);
    });
}());

// Language preference persistence
(function () {
    const isDE = window.location.pathname.indexOf('/de/') !== -1 || window.location.pathname.endsWith('/de');
    const currentLang = isDE ? 'de' : 'en';

    // Redirect on load if saved language differs from current page.
    // Skip redirect when navigating from the other language version to avoid redirect loops.
    const savedLang = localStorage.getItem('lang');
    if (savedLang && savedLang !== currentLang) {
        const fromOtherLang = document.referrer.indexOf('/de/') !== -1 || document.referrer.endsWith('/de');
        if (!fromOtherLang) {
            window.location.href = savedLang === 'de' ? 'de/' : '../';
        }
    }

    // Save language preference when a language link is clicked.
    // href="de/" → DE, href="../" → EN, href="" → current (no change needed, just persist)
    document.querySelectorAll('.lang-dropdown .dropdown-item').forEach(function (link) {
        link.addEventListener('click', function () {
            const href = this.getAttribute('href');
            const lang = href.indexOf('de') !== -1 ? 'de' : href === '' ? currentLang : 'en';
            localStorage.setItem('lang', lang);
        });
    });
}());

// Smooth Scrolling for anchor links
document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        var target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    });
});

// Back to Top Button + Navbar shadow on scroll
(function () {
    var btn = document.getElementById('backToTop');
    var navbar = document.querySelector('.site-navbar');
    window.addEventListener('scroll', function () {
        btn.classList.toggle('visible', window.scrollY > 400);
        navbar.classList.toggle('scrolled', window.scrollY > 10);
    });
    btn.addEventListener('click', function () {
        window.scrollTo({ top: 0, behavior: 'smooth' });
    });
}());

// Copy Buttons for code blocks
(function () {
    document.querySelectorAll('.code-example').forEach(function (block) {
        var btn = document.createElement('button');
        btn.className = 'copy-btn';
        btn.innerHTML = '<i class="bi bi-clipboard"></i>';
        btn.title = 'Copy to clipboard';
        block.appendChild(btn);

        btn.addEventListener('click', function () {
            var code = block.querySelector('code');
            navigator.clipboard.writeText(code.innerText).then(function () {
                btn.innerHTML = '<i class="bi bi-check-lg"></i>';
                btn.classList.add('copied');
                setTimeout(function () {
                    btn.innerHTML = '<i class="bi bi-clipboard"></i>';
                    btn.classList.remove('copied');
                }, 2000);
            }).catch(function () {});
        });
    });
}());

// Navbar active state on scroll
(function () {
    var sections = document.querySelectorAll('section[id]');
    var navLinks = document.querySelectorAll('.navbar-nav a[href^="#"]');

    var observer = new IntersectionObserver(function (entries) {
        if (window.scrollY === 0) {
            navLinks.forEach(function (link) { link.classList.remove('active'); });
            return;
        }
        entries.forEach(function (entry) {
            if (entry.isIntersecting) {
                navLinks.forEach(function (link) { link.classList.remove('active'); });
                var active = document.querySelector('.navbar-nav a[href="#' + entry.target.id + '"]');
                if (active) { active.classList.add('active'); }
            }
        });
    }, { rootMargin: '-20% 0px -65% 0px' });

    sections.forEach(function (section) { observer.observe(section); });

    // Deactivate all links when scrolled back to top
    window.addEventListener('scroll', function () {
        if (window.scrollY === 0) {
            navLinks.forEach(function (link) { link.classList.remove('active'); });
        }
    });
}());
