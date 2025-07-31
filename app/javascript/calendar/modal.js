export default function setupReservationModal() {
  window.openReservationModal = function(reservationId = null, dateStr = null) {
    const modal = document.getElementById('reservationModal');
    if (!modal) return;

    resetReservationModalFields(reservationId, dateStr);

    if (reservationId) {
      fetch(`/admin/reservations/${reservationId}.json`)
        .then(res => res.json())
        .then(data => {
          if (data.success !== false) {
            populateReservationModal(data);
          } else {
            window.showMessage('予約データの取得に失敗しました', 'danger');
          }
        });
    }

    const bootstrapModal = new bootstrap.Modal(modal);
    bootstrapModal.show();
  };

  window.closeReservationModal = function() {
    const modal = document.getElementById('reservationModal');
    if (!modal) return;
    const bootstrapModal = bootstrap.Modal.getInstance(modal);
    if (bootstrapModal) bootstrapModal.hide();
  };

  function resetReservationModalFields(reservationId, dateStr) {
    const fieldMap = {
      reservationId: reservationId || '',
      reservationCourse: '60分',
      reservationStatus: 'tentative',
      reservationNote: '',
      cancellationReason: ''
    };
    Object.entries(fieldMap).forEach(([id, val]) => {
      const el = document.getElementById(id);
      if (el) el.value = val;
    });

    const dateEl = document.getElementById('reservationDate');
    const timeEl = document.getElementById('reservationTime');
    if (dateStr) {
      const [date, time] = dateStr.split('T');
      if (dateEl) dateEl.value = date;
      if (timeEl) timeEl.value = time?.substring(0, 5) || '';
    }

    document.getElementById('newUserToggle').checked = false;
    document.getElementById('existingUserSection').style.display = 'block';
    document.getElementById('newUserSection').style.display = 'none';

    updateCancellationReasonVisibility();
  }

  function populateReservationModal(data) {
    const mapping = {
      reservationUserId: 'user_id',
      reservationCourse: 'course',
      reservationStatus: 'status',
      reservationNote: 'note',
      cancellationReason: 'cancellation_reason'
    };

    Object.entries(mapping).forEach(([fieldId, key]) => {
      const el = document.getElementById(fieldId);
      if (el) el.value = data[key] || '';
    });

    if (data.start_time) {
      const start = new Date(data.start_time);
      document.getElementById('reservationDate').value = start.toISOString().split('T')[0];
      document.getElementById('reservationTime').value = start.toTimeString().substring(0, 5);
    }

    updateCancellationReasonVisibility();
  }

  function updateCancellationReasonVisibility() {
    const status = document.getElementById('reservationStatus').value;
    const reasonArea = document.getElementById('cancellationReasonArea');
    if (reasonArea) {
      reasonArea.style.display = status === 'cancelled' ? 'block' : 'none';
      const reasonInput = document.getElementById('cancellationReason');
      if (reasonInput) reasonInput.required = (status === 'cancelled');
    }
  }

  const statusSelect = document.getElementById('reservationStatus');
  if (statusSelect) {
    statusSelect.addEventListener('change', updateCancellationReasonVisibility);
  }
}
