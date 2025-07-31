export default function setupIntervalControls() {
  const toggle = document.getElementById('individualIntervalToggle');
  const slider = document.getElementById('individual-interval-slider');
  const input = document.getElementById('individual-interval-input');
  const preview = document.getElementById('individual-interval-preview');
  const systemArea = document.getElementById('systemIntervalArea');
  const individualArea = document.getElementById('individualIntervalArea');
  const statusBadge = document.getElementById('interval-status-badge');
  const presetButtons = document.querySelectorAll('.individual-preset-btn');

  if (!toggle) return;

  toggle.addEventListener('change', () => {
    const checked = toggle.checked;
    individualArea.style.display = checked ? 'block' : 'none';
    systemArea.style.display = checked ? 'none' : 'block';
    statusBadge.textContent = checked ? '個別設定' : 'システム設定';
    statusBadge.className = checked ? 'badge bg-warning text-dark ms-2' : 'badge bg-primary ms-2';
    updatePreview(checked ? input.value : null);
  });

  slider.addEventListener('input', () => {
    input.value = slider.value;
    updatePreview(slider.value);
    updatePresetHighlight(slider.value);
  });

  input.addEventListener('input', () => {
    slider.value = input.value;
    updatePreview(input.value);
    updatePresetHighlight(input.value);
  });

  presetButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      slider.value = btn.dataset.value;
      input.value = btn.dataset.value;
      updatePreview(btn.dataset.value);
      updatePresetHighlight(btn.dataset.value);
    });
  });

  function updatePreview(value) {
    if (!preview) return;
    const minutes = parseInt(value);
    preview.innerHTML = minutes === 0 ?
      '<div class="alert alert-secondary py-2"><small>インターバルなし（この予約専用）</small></div>' :
      `<div class="alert alert-warning py-2"><small>${minutes}分の整理時間（この予約専用）</small></div>`;
  }

  function updatePresetHighlight(value) {
    presetButtons.forEach(btn => {
      btn.classList.toggle('btn-secondary', btn.dataset.value === value);
      btn.classList.toggle('btn-outline-secondary', btn.dataset.value !== value);
    });
  }

  const applyBtn = document.getElementById('applyIndividualInterval');
  if (applyBtn) {
    applyBtn.addEventListener('click', () => {
      const reservationId = document.getElementById('reservationId').value;
      const minutes = toggle.checked ? parseInt(input.value) : null;
      fetch(`/admin/reservations/${reservationId}/update_individual_interval`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ individual_interval_minutes: minutes })
      })
        .then(res => res.json())
        .then(data => {
          if (data.success) {
            window.showMessage('インターバルを更新しました', 'success');
            if (window.pageCalendar) window.pageCalendar.refetchEvents();
          } else {
            window.showMessage(data.error || 'インターバル更新失敗', 'danger');
          }
        });
    });
  }

  const resetBtn = document.getElementById('resetIndividualInterval');
  if (resetBtn) {
    resetBtn.addEventListener('click', () => {
      const reservationId = document.getElementById('reservationId').value;
      if (!confirm('インターバル設定をリセットしますか？')) return;
      fetch(`/admin/reservations/${reservationId}/reset_individual_interval`, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })
        .then(res => res.json())
        .then(data => {
          if (data.success) {
            toggle.checked = false;
            toggle.dispatchEvent(new Event('change'));
            window.showMessage('インターバル設定をリセットしました', 'success');
            if (window.pageCalendar) window.pageCalendar.refetchEvents();
          } else {
            window.showMessage(data.error || 'リセット失敗', 'danger');
          }
        });
    });
  }
}