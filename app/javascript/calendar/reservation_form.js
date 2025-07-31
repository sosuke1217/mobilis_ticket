export default function setupReservationForm() {
  const saveBtn = document.getElementById('saveReservationBtn');
  const newUserToggle = document.getElementById('newUserToggle');
  const existingUserSection = document.getElementById('existingUserSection');
  const newUserSection = document.getElementById('newUserSection');

  if (saveBtn) {
    saveBtn.addEventListener('click', saveReservation);
  }

  if (newUserToggle) {
    newUserToggle.addEventListener('change', () => {
      if (newUserToggle.checked) {
        existingUserSection.style.display = 'none';
        newUserSection.style.display = 'block';
      } else {
        existingUserSection.style.display = 'block';
        newUserSection.style.display = 'none';
      }
    });
  }

  function saveReservation() {
    if (!validateReservationForm()) return;

    const reservationId = document.getElementById('reservationId').value;
    const isNewUser = newUserToggle.checked;

    const data = {
      reservation: {
        course: document.getElementById('reservationCourse').value,
        note: document.getElementById('reservationNote').value,
        status: document.getElementById('reservationStatus').value,
        start_time: `${document.getElementById('reservationDate').value}T${document.getElementById('reservationTime').value}:00`,
        cancellation_reason: document.getElementById('cancellationReason').value
      }
    };

    if (isNewUser) {
      data.new_user = {
        name: document.getElementById('newUserName').value,
        phone_number: document.getElementById('newUserPhone').value,
        email: document.getElementById('newUserEmail').value,
        birth_date: document.getElementById('newUserBirthDate').value,
        address: document.getElementById('newUserAddress').value,
        admin_memo: document.getElementById('newUserMemo').value
      };
    } else {
      data.reservation.user_id = document.getElementById('reservationUserId').value;
    }

    const url = reservationId ? `/admin/reservations/${reservationId}` : '/admin/reservations';
    const method = reservationId ? 'PATCH' : 'POST';

    saveBtn.disabled = true;
    saveBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i>保存中...';

    fetch(url, {
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      },
      body: JSON.stringify(data)
    })
      .then(res => res.json())
      .then(data => {
        if (data.success !== false) {
          window.showMessage(reservationId ? '予約を更新しました' : '予約を作成しました', 'success');
          window.closeReservationModal();
          if (window.pageCalendar) window.pageCalendar.refetchEvents();
        } else {
          const err = data.error || (data.errors && data.errors.join(', ')) || '保存に失敗しました';
          window.showMessage(err, 'danger');
        }
      })
      .catch(err => {
        console.error('❌ Save failed:', err);
        window.showMessage('保存中にエラーが発生しました', 'danger');
      })
      .finally(() => {
        saveBtn.disabled = false;
        saveBtn.innerHTML = '<i class="fas fa-save me-1"></i>保存';
      });
  }

  function validateReservationForm() {
    const isNewUser = newUserToggle.checked;
    const errors = [];

    if (isNewUser) {
      if (!document.getElementById('newUserName').value.trim()) {
        errors.push('ユーザー名を入力してください');
      }
    } else {
      if (!document.getElementById('reservationUserId').value) {
        errors.push('ユーザーを選択してください');
      }
    }

    if (!document.getElementById('reservationDate').value)
      errors.push('予約日を選択してください');
    if (!document.getElementById('reservationTime').value)
      errors.push('開始時間を選択してください');
    if (!document.getElementById('reservationCourse').value)
      errors.push('コースを選択してください');

    const status = document.getElementById('reservationStatus').value;
    if (status === 'cancelled') {
      const reason = document.getElementById('cancellationReason').value.trim();
      if (!reason) {
        errors.push('キャンセル理由を入力してください');
      }
    }

    if (errors.length > 0) {
      window.showMessage(errors.join('\n'), 'danger');
      return false;
    }

    return true;
  }
}