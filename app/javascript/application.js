
document.addEventListener("turbo:load", () => {
  console.log("🔥 turbo:load fired");

  if (window.Chartkick) {
    Chartkick.eachChart(chart => chart.redraw());
  }

  const calendarEl = document.getElementById("calendar");
  if (!calendarEl) {
    console.log("⚠️ calendarEl not found");
    return;
  }

  if (calendarEl.dataset.initialized === "true") {
    console.log("🔁 calendar already initialized");
    return;
  }
  calendarEl.dataset.initialized = "true";

  const calendar = new FullCalendar.Calendar(calendarEl, {
    initialView: "timeGridWeek",
    slotMinTime: "10:00:00",
    slotMaxTime: "20:00:00",
    locale: "ja",
    headerToolbar: {
      left: "prev,next today",
      center: "title",
      right: "timeGridDay,timeGridWeek"
    },
    events: "/admin/reservations.json"
  });

  calendar.render();
});

window.addEventListener("turbo:before-cache", () => {
  console.log("🧹 turbo:before-cache cleaning up calendar");
  const calendarEl = document.getElementById("calendar");
  if (calendarEl) {
    calendarEl.innerHTML = "";
    calendarEl.removeAttribute("data-initialized");
  }
});
