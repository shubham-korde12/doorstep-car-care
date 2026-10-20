(() => {
  const form = document.querySelector('#booking-form');
  const planSelect = document.querySelector('#plan-select');
  const mobileMenu = document.querySelector('.menu-toggle');
  const nav = document.querySelector('.main-nav');
  const year = document.querySelector('#year');
  const phoneNumber = '917498557226';

  if (year) year.textContent = String(new Date().getFullYear());

  document.querySelectorAll('.choose-plan').forEach((button) => {
    button.addEventListener('click', () => {
      const plan = button.dataset.plan;
      if (planSelect && plan) {
        const option = Array.from(planSelect.options).find((item) => item.text === plan);
        if (option) planSelect.value = option.value;
      }
    });
  });

  if (mobileMenu && nav) {
    mobileMenu.addEventListener('click', () => {
      const isOpen = nav.classList.toggle('open');
      mobileMenu.setAttribute('aria-expanded', String(isOpen));
      mobileMenu.setAttribute('aria-label', isOpen ? 'Close navigation' : 'Open navigation');
    });
    nav.querySelectorAll('a').forEach((link) => {
      link.addEventListener('click', () => {
        nav.classList.remove('open');
        mobileMenu.setAttribute('aria-expanded', 'false');
        mobileMenu.setAttribute('aria-label', 'Open navigation');
      });
    });
  }

  if (form) {
    form.addEventListener('submit', (event) => {
      event.preventDefault();
      if (!form.reportValidity()) return;
      const values = new FormData(form);
      const message = [
        'Hi DOORSTEP CAR CARE! I would like to request a booking.',
        '',
        `Name: ${String(values.get('name') || '').trim()}`,
        `Mobile: ${String(values.get('mobile') || '').trim()}`,
        `Society / locality: ${String(values.get('society') || '').trim()}`,
        `Car model: ${String(values.get('car') || '').trim()}`,
        `Interested plan: ${String(values.get('plan') || '').trim()}`,
        `Preferred day / timing: ${String(values.get('timing') || '').trim() || 'Flexible'}`,
        '',
        'Please confirm service availability and the next steps. I understand this is a request and is not confirmed until your team replies.'
      ].join('\n');
      const url = `https://wa.me/${phoneNumber}?text=${encodeURIComponent(message)}`;
      window.open(url, '_blank', 'noopener,noreferrer');
    });
  }
})();
