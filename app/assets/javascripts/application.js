//= require Chart.bundle
//= require chartkick

document.addEventListener("DOMContentLoaded", () => {
  const datePicker = document.getElementById("date-picker");
  if (datePicker) {
    datePicker.addEventListener("change", () => {
      const date = datePicker.value;
      fetch(`/admin/reservations/available_slots?date=${date}`)
        .then(res => res.text())
        .then(html => {
          document.getElementById("available-times").innerHTML = html;
        });
    });
  }
});