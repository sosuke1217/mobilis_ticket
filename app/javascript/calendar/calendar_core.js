export default function initializeCalendar() {
  const FC = window.FullCalendar;
  if (!FC) {
    console.error("❌ FullCalendar is not available in global scope");
    return;
  }

  const calendarEl = document.getElementById('calendar');
  if (!calendarEl) return;

  const calendar = new FC.Calendar(calendarEl, {
    plugins: [FC.TimeGridPlugin],
    initialView: 'timeGridWeek',
    headerToolbar: {
      left: 'prev,next today',
      center: 'title',
      right: 'dayGridMonth,timeGridWeek,timeGridDay'
    },
    locale: 'ja',
    height: 'auto',
    editable: true,
    selectable: true,
    selectMirror: true,
    dayMaxEvents: true,
    weekends: !window.systemSettings.sundayClosed,
    businessHours: {
      daysOfWeek: window.systemSettings.sundayClosed ? [1, 2, 3, 4, 5, 6] : [0, 1, 2, 3, 4, 5, 6],
      startTime: `${window.systemSettings.businessHoursStart.toString().padStart(2, '0')}:00`,
      endTime: `${window.systemSettings.businessHoursEnd.toString().padStart(2, '0')}:00`,
    },
    slotDuration: `00:${window.systemSettings.slotIntervalMinutes.toString().padStart(2, '0')}:00`,
    slotMinTime: `${window.systemSettings.businessHoursStart.toString().padStart(2, '0')}:00:00`,
    slotMaxTime: `${window.systemSettings.businessHoursEnd.toString().padStart(2, '0')}:00:00`,
    events: '/admin/reservations.json',
    eventClick: function(info) {
      const eventType = info.event.extendedProps.type;
      if (eventType === 'interval') {
        const reservationId = info.event.extendedProps.reservation_id;
        if (reservationId) {
          window.showMessage(`予約ID: ${reservationId} の詳細を表示します`, 'info');
          window.openReservationModal(reservationId);
        }
        return;
      }
      if (eventType === 'reservation' || !eventType) {
        window.openReservationModal(info.event.id);
      }
    },
    eventDrop: function(info) {
      const eventType = info.event.extendedProps.type;
      if (eventType === 'interval') {
        info.revert();
        window.showMessage('インターバル時間は移動できません', 'warning');
        return;
      }
      window.updateReservationTime(info.event, info.revert);
    },
    eventResize: function(info) {
      if (info.event.extendedProps.type === 'interval') {
        info.revert();
        window.showMessage('インターバル時間はリサイズできません', 'warning');
      }
    },
    select: function(info) {
      window.openReservationModal(null, info.startStr);
    },
    eventDidMount: function(info) {
      const eventType = info.event.extendedProps.type;
      if (eventType === 'interval') {
        info.el.classList.add('interval-event');
      } else {
        info.el.classList.add('reservation-event');
      }
    }
  });

  calendar.render();
  window.pageCalendar = calendar;
}
