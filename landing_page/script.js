document.addEventListener('DOMContentLoaded', () => {
    // --- Force Unregister Service Workers ---
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.getRegistrations().then(registrations => {
            registrations.forEach(registration => {
                if (registration.scope === window.location.origin + '/') {
                    registration.unregister();
                }
            });
        });
    }

    // --- Theme Logic ---
    const themeToggle = document.getElementById('theme-toggle');
    const themeIcon = themeToggle.querySelector('i');

    // Check saved theme or system preference
    const savedTheme = localStorage.getItem('theme');
    const systemPrefersLight = window.matchMedia('(prefers-color-scheme: light)').matches;

    // Default to dark unless explicitly light
    if (savedTheme === 'light' || (!savedTheme && systemPrefersLight)) {
        document.body.classList.add('light-mode');
        themeIcon.classList.replace('fa-moon', 'fa-sun');
    }

    // Toggle Click Event
    themeToggle.addEventListener('click', () => {
        document.body.classList.toggle('light-mode'); // Switch class

        // Update Icon with spinning animation
        themeIcon.style.transform = 'rotate(180deg) scale(0.5)';
        themeIcon.style.opacity = '0';

        setTimeout(() => {
            if (document.body.classList.contains('light-mode')) {
                themeIcon.classList.replace('fa-moon', 'fa-sun');
                localStorage.setItem('theme', 'light');
            } else {
                themeIcon.classList.replace('fa-sun', 'fa-moon');
                localStorage.setItem('theme', 'dark'); // Save dark explicitly
            }
            themeIcon.style.transform = 'rotate(0) scale(1)';
            themeIcon.style.opacity = '1';
        }, 300);
    });


    // --- Scroll Reveal Observer ---
    const revealElements = document.querySelectorAll('.reveal-up');

    const revealObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('active');
            }
        });
    }, {
        threshold: 0.1,
        rootMargin: "0px 0px -50px 0px"
    });

    revealElements.forEach(el => revealObserver.observe(el));

    // --- ScrollSpy for Navbar ---
    const sections = document.querySelectorAll('section');
    const navItems = document.querySelectorAll('.nav-links a');

    function updateActiveSection() {
        let current = '';

        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.clientHeight;
            // Check if section is approximately in view (viewport center)
            if (scrollY >= (sectionTop - 300)) {
                current = section.getAttribute('id');
            }
        });

        navItems.forEach(a => {
            a.classList.remove('active');
            // Strict check to avoid empty string matching everything
            if (current && a.getAttribute('href').endsWith('#' + current)) {
                a.classList.add('active');
            }
        });
    }

    window.addEventListener('scroll', updateActiveSection);
    // Initial check
    updateActiveSection();


    // --- Mobile Menu Toggle ---
    const mobileToggle = document.querySelector('.mobile-toggle');
    const navLinks = document.querySelector('.nav-links');
    // const navItems = document.querySelectorAll('.nav-links a'); // Already defined at line 67

    if (mobileToggle && navLinks) {
        mobileToggle.addEventListener('click', () => {
            navLinks.classList.toggle('active');
            const icon = mobileToggle.querySelector('i');

            if (navLinks.classList.contains('active')) {
                icon.classList.remove('fa-bars');
                icon.classList.add('fa-xmark');
                document.body.style.overflow = 'hidden';
            } else {
                icon.classList.remove('fa-xmark');
                icon.classList.add('fa-bars');
                document.body.style.overflow = '';
            }
        });

        navItems.forEach(item => {
            item.addEventListener('click', () => {
                navLinks.classList.remove('active');
                const icon = mobileToggle.querySelector('i');
                icon.classList.remove('fa-xmark');
                icon.classList.add('fa-bars');
                document.body.style.overflow = '';
            });
        });
    }

    // --- Device Detection for Hero Button ---
    const ua = navigator.userAgent.toLowerCase();
    const btn = document.getElementById('hero-btn');
    const btnText = document.getElementById('btn-text');
    const btnIcon = btn ? btn.querySelector('i') : null;

    if (btn && btnText && btnIcon) {
        if (ua.includes('android')) {
            btn.href = "#";
            btnText.textContent = "Coming Soon";
            btnIcon.className = "fa-brands fa-google-play";
            btn.style.opacity = "0.8";
            btn.style.cursor = "default";
        } else {
            btn.href = "/app/";
            if (ua.includes('iphone') || ua.includes('ipad') || ua.includes('macintosh')) {
                btnText.textContent = "Launch on iOS";
                btnIcon.className = "fa-brands fa-apple";
            } else if (ua.includes('windows')) {
                btnText.textContent = "Launch Web App";
                btnIcon.className = "fa-solid fa-rocket";
            } else {
                btnText.textContent = "Launch Web App";
                btnIcon.className = "fa-solid fa-rocket";
            }
        }
    }

    // --- Navbar Scroll Effect ---
    const navbar = document.querySelector('.navbar');
    window.addEventListener('scroll', () => {
        if (window.scrollY > 50) {
            navbar.classList.add('scrolled');
        } else {
            navbar.classList.remove('scrolled');
        }
    });

    // --- 3D Tilt Effect for Bento Cards ---
    const cards = document.querySelectorAll('.bento-card');

    cards.forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;

            const centerX = rect.width / 2;
            const centerY = rect.height / 2;

            const rotateX = ((y - centerY) / centerY) * -10;
            const rotateY = ((x - centerX) / centerX) * 10;

            card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(1.02)`;
            // Use backgroundImage to layer gradient over existing background-color (var(--bg-card))
            card.style.backgroundImage = `radial-gradient(circle at ${x}px ${y}px, rgba(255,255,255,0.1), transparent 40%)`;
        });

        card.addEventListener('mouseleave', () => {
            card.style.transform = `perspective(1000px) rotateX(0) rotateY(0) scale(1)`;
            card.style.backgroundImage = ''; // Remove gradient, keep base color
        });
    });
});
