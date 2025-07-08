document.addEventListener("turbo:load", () => {
  document.querySelectorAll("form.button_to .use-ticket-btn").forEach(button => {
    const form = button.closest("form");
    if (!form) return;

    form.addEventListener("submit", (event) => {
      const confirmMessage = button.dataset.confirmRemote;
      if (confirmMessage && !window.confirm(confirmMessage)) {
        event.preventDefault();
      }
    }, { once: true }); // 複数回バインドされないように
  });
});
