(function () {
    function processLinks() {
        var links = document.querySelectorAll('a[href]');
        links.forEach(function (link) {
            var href = link.getAttribute('href');
            if (href && (href.startsWith('http://') || href.startsWith('https://'))) {
                try {
                    var url = new URL(href);
                    if (url.hostname !== window.location.hostname) {
                        link.setAttribute('target', '_blank');
                        link.setAttribute('rel', 'noopener noreferrer');
                    }
                } catch (e) {}
            }
        });
    }

    if (typeof document$ !== 'undefined') {
        document$.subscribe(processLinks);
    } else {
        document.addEventListener('DOMContentLoaded', processLinks);
    }
}());
