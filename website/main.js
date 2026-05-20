import './style.css'

document.addEventListener('DOMContentLoaded', () => {
  const nodes = document.querySelectorAll('.node');
  const stages = document.querySelectorAll('.stage');
  const progressLine = document.getElementById('timeline-progress');

  if (nodes.length === 0) return;

  let currentStep = 0;
  const totalSteps = nodes.length;

  function updateStep(step) {
    // Update nodes
    nodes.forEach((n, i) => {
      if (i <= step) {
        n.classList.add('active');
      } else {
        n.classList.remove('active');
      }
      // Only the exact active step needs the special shadow pulse
      if (i === step) {
        n.style.transform = 'scale(1.2)';
      } else {
        n.style.transform = 'scale(1)';
      }
    });

    // Update stages
    stages.forEach((s, i) => {
      s.classList.toggle('active', i === step);
    });

    // Update progress line width
    const progress = (step / (totalSteps - 1)) * 100;
    progressLine.style.width = `${progress}%`;
  }

  setInterval(() => {
    currentStep = (currentStep + 1) % totalSteps;
    updateStep(currentStep);
  }, 1350); // loop every 1.5 seconds

  // Hover Effect Grid Logic
  const hoverGrid = document.getElementById('hover-grid');
  const cursorBg = document.getElementById('hover-cursor-bg');
  const hoverWrappers = document.querySelectorAll('.hover-card-wrapper');

  if (hoverGrid && cursorBg) {
    hoverWrappers.forEach(wrapper => {
      wrapper.addEventListener('mouseenter', () => {
        const rect = wrapper.getBoundingClientRect();
        const gridRect = hoverGrid.getBoundingClientRect();

        cursorBg.style.width = `${rect.width}px`;
        cursorBg.style.height = `${rect.height}px`;
        cursorBg.style.transform = `translate(${rect.left - gridRect.left}px, ${rect.top - gridRect.top}px)`;
        cursorBg.style.opacity = '1';
      });
    });

    hoverGrid.addEventListener('mouseleave', () => {
      cursorBg.style.opacity = '0';
    });
  }

  // Hero Search Placeholder Typewriter Animation
  const searchInput = document.querySelector('.hero-search-input');
  if (searchInput) {
    const phrases = [
      "Muje F10 mein Plumber Chayie",
      "I need Car Mechanic in G8",
      "AC servicing in DHA Phase 2"
    ];
    let phraseIdx = 0;
    let charIdx = 0;
    let isDeleting = false;

    function typeWriter() {
      const currentText = phrases[phraseIdx];

      if (isDeleting) {
        searchInput.setAttribute('placeholder', currentText.substring(0, charIdx - 1));
        charIdx--;
      } else {
        searchInput.setAttribute('placeholder', currentText.substring(0, charIdx + 1) + "|");
        charIdx++;
      }

      let typeSpeed = isDeleting ? 15 : 35;

      if (!isDeleting && charIdx === currentText.length) {
        typeSpeed = 300; // Pause when finished typing
        isDeleting = true;
        searchInput.setAttribute('placeholder', currentText); // Remove cursor when paused
      } else if (isDeleting && charIdx === 0) {
        isDeleting = false;
        phraseIdx = (phraseIdx + 1) % phrases.length;
        typeSpeed = 500; // Pause before next word
      }

      setTimeout(typeWriter, typeSpeed);
    }

    setTimeout(typeWriter, 1000);
  }

  // Scroll Spy for Navigation Links & Glassmorphism Navbar
  const sections = document.querySelectorAll('section, header');
  const navLinks = document.querySelectorAll('.nav-links-center a');
  const navPill = document.querySelector('.nav-floating-pill');

  window.addEventListener('scroll', () => {
    // Glassmorphism toggle
    if (window.scrollY > 600) {
      navPill.classList.add('scrolled');
    } else {
      navPill.classList.remove('scrolled');
    }

    let current = '';
    sections.forEach(section => {
      const sectionTop = section.offsetTop;
      if (pageYOffset >= (sectionTop - 150)) {
        current = section.getAttribute('id');
      }
    });

    navLinks.forEach(link => {
      link.classList.remove('active');
      const href = link.getAttribute('href');

      if (current) {
        if (href === `#${current}`) {
          link.classList.add('active');
        }
      } else {
        if (href === '#' || href === '#overview') {
          link.classList.add('active');
        }
      }
    });
  });
});
