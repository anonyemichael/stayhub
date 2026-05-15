document.addEventListener('DOMContentLoaded', () => {
    // --- 1. Navbar Scroll, Mobile Menu & Theme Toggle ---
    const navbar = document.getElementById('navbar');
    const mobileToggle = document.getElementById('mobile-toggle');
    const themeToggle = document.getElementById('themeToggle');
    const navLinksContainer = document.querySelector('.nav-links');
    const navLinksList = document.querySelectorAll('.nav-links a');
    
    // Theme Logic
    const currentTheme = localStorage.getItem('theme') || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    if (currentTheme === 'dark') {
        document.documentElement.setAttribute('data-theme', 'dark');
    }
    // Safety: Clear reality-shift on load
    document.body.classList.remove('reality-shift');

    // Global Fail-Safe for touch devices: Clear reality-shift on any touch if it's stuck
    document.addEventListener('touchstart', () => {
        if (document.body.classList.contains('reality-shift')) {
            document.body.classList.remove('reality-shift');
        }
    }, { passive: true });

    if (themeToggle) {
        themeToggle.addEventListener('click', () => {
            // Trigger Dimension Ripple on Body
            document.body.classList.add('reality-shift');
            themeToggle.classList.add('portal-active');
            
            // Backup removal (Safety)
            setTimeout(() => {
                document.body.classList.remove('reality-shift');
            }, 1000);

            setTimeout(() => {
                try {
                    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
                    const newTheme = isDark ? 'light' : 'dark';
                    
                    document.documentElement.setAttribute('data-theme', newTheme);
                    localStorage.setItem('theme', newTheme);
                } catch (e) {
                    console.error("Theme toggle failed", e);
                } finally {
                    document.body.classList.remove('reality-shift');
                    themeToggle.classList.remove('portal-active');
                }
            }, 600);
        });
    }

    // Scroll Detector
    window.addEventListener('scroll', () => {
        if (navbar && window.scrollY > 50) {
            navbar.classList.add('scrolled');
        } else if (navbar) {
            navbar.classList.remove('scrolled');
        }
    });

    if (mobileToggle && navLinksContainer) {
        mobileToggle.addEventListener('click', () => {
            navLinksContainer.classList.toggle('active');
            const icon = mobileToggle.querySelector('i');
            if (icon) {
                icon.classList.toggle('fa-bars-staggered');
                icon.classList.toggle('fa-xmark');
            }
        });
    }

    navLinksList.forEach(link => {
        link.addEventListener('click', () => {
            if (navLinksContainer) navLinksContainer.classList.remove('active');
            if (mobileToggle) {
                const icon = mobileToggle.querySelector('i');
                if (icon) {
                    icon.classList.add('fa-bars-staggered');
                    icon.classList.remove('fa-xmark');
                }
            }
        });
    });

    // --- 2. Scroll Spy (Active Section Tracker) ---
    const spySections = document.querySelectorAll('section[id], header[id]');

    function updateScrollSpy() {
        let current = "";
        const scrollPos = window.scrollY || window.pageYOffset;
        
        spySections.forEach((section) => {
            const sectionTop = section.offsetTop;
            if (scrollPos >= sectionTop - 250) {
                current = section.getAttribute("id");
            }
        });

        navLinksList.forEach((link) => {
            link.classList.remove("active");
            if (link.getAttribute("href") === `#${current}`) {
                link.classList.add("active");
            }
        });
    }

    window.addEventListener('scroll', updateScrollSpy);
    updateScrollSpy(); // Run on load

    // --- 3. Intersection Observer for Reveal Animations ---
    const observerOptions = {
        threshold: 0.1,
        rootMargin: "0px 0px -50px 0px"
    };

    const revealObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('active');
            }
        });
    }, observerOptions);

    const revealElements = document.querySelectorAll('.reveal, .reveal-3d');
    revealElements.forEach((el) => {
        revealObserver.observe(el);
        
        // Immediate check: if element is already in view, reveal it
        const rect = el.getBoundingClientRect();
        if (rect.top < window.innerHeight && rect.bottom > 0) {
            el.classList.add('active');
        }
    });

    // --- 3D Tilt Cards (Vanilla JS Implementation) ---
    const tiltCards = document.querySelectorAll('.tilt-card');

    tiltCards.forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            // Calculate mouse position relative to the center of the card
            const x = e.clientX - rect.left - rect.width / 2;
            const y = e.clientY - rect.top - rect.height / 2;

            // Calculate rotation (adjust divisor for sensitivity)
            // Multiply by -1 to invert the tilt direction if desired
            const rotateX = (y / rect.height) * -20; 
            const rotateY = (x / rect.width) * 20;

            card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.02, 1.02, 1.02)`;
            card.style.transition = 'none'; // Remove transition during movement for smoothness
        });

        card.addEventListener('mouseleave', () => {
            card.style.transform = `perspective(1000px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)`;
            card.style.transition = 'transform 0.5s cubic-bezier(0.25, 1, 0.5, 1)';
        });
        
        card.addEventListener('mouseenter', () => {
             card.style.transition = 'transform 0.1s cubic-bezier(0.25, 1, 0.5, 1)';
        });
    });

    // --- 4. WhatsApp Property Form Logic ---
    const propForm = document.getElementById('propertyForm');
    if(propForm) {
        propForm.addEventListener('submit', function(e) {
            e.preventDefault();
            
            const name = document.getElementById('ownerName').value;
            const phone = document.getElementById('ownerPhone').value;
            const propName = document.getElementById('propName').value;
            const location = document.getElementById('propLocation').value;

            const message = `*StayHub Property Enrollment*%0A%0A` +
                            `*Owner:* ${name}%0A` +
                            `*Phone:* ${phone}%0A%0A` +
                            `*Property Name:* ${propName}%0A` +
                            `*Location:* ${location}%0A%0A` +
                            `_Please contact me to finalize my listing._`;

            window.open(`https://wa.me/233533311532?text=${message}`, '_blank');
        });
    }

    // --- 5. Smart Device-Aware Buttons ---
    const userAgent = navigator.userAgent || navigator.vendor || window.opera;
    const isAndroid = /android/i.test(userAgent);
    const isIOS = /iPad|iPhone|iPod/.test(userAgent) && !window.MSStream;
    const isMobile = isAndroid || isIOS;
    
    const heroBtn = document.querySelector('.hero .btn-primary');
    const navBtn = document.querySelector('.navbar .btn-primary');
    const playStoreUrl = "https://play.google.com/store/apps/details?id=com.stayhub.app";

    if (heroBtn && navBtn) {
        if (isAndroid) {
            // Android: Directly to Play Store
            heroBtn.href = playStoreUrl;
            navBtn.href = playStoreUrl;
            heroBtn.innerHTML = 'Download for Android <i class="fa-brands fa-android"></i>';
            navBtn.innerText = 'Get Android App';
        } else if (isIOS) {
            // iOS: To PWA Web App
            heroBtn.href = "/app/";
            navBtn.href = "/app/";
            heroBtn.innerHTML = 'Launch PWA App <i class="fa-solid fa-rocket"></i>';
            navBtn.innerText = 'Launch App';
        } else {
            // Desktop: Scroll to Downloads or Launch Web
            heroBtn.href = "#downloads";
            navBtn.href = "/app/";
            heroBtn.innerHTML = 'Launch Web App <i class="fa-solid fa-rocket"></i>';
            navBtn.innerText = 'Open Dashboard';
            
            heroBtn.addEventListener('click', (e) => {
                if (heroBtn.getAttribute('href') === '#downloads') {
                    e.preventDefault();
                    document.querySelector('#downloads').scrollIntoView({ behavior: 'smooth' });
                }
            });
        }
    }

    // --- Video Auto-Play Enforcer ---
    const bentoVideo = document.getElementById('hero-bento-video');
    if (bentoVideo) {
        // Try to play immediately
        const playVideo = () => {
            bentoVideo.play().catch(error => {
                console.log("Autoplay was prevented, waiting for interaction.");
            });
        };
        
        playVideo();
        
        // Fallback: Play on first interaction if blocked
        document.addEventListener('click', () => {
            if (bentoVideo.paused) {
                bentoVideo.play();
            }
        }, { once: true });
    }
});
