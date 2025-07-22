// app/javascript/controllers/reservation_form_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    console.log("Reservation form controller connected");

    const dateInput = this.element.querySelector("#date-picker");
    const availableTimesContainer = this.element.querySelector("#available-times");

    if (dateInput && availableTimesContainer) {
      dateInput.addEventListener("change", () => {
        const selectedDate = dateInput.value;
        if (!selectedDate) return;

        fetch(`/admin/reservations/available_slots?date=${selectedDate}`)
          .then((res) => res.text())
          .then((html) => {
            availableTimesContainer.innerHTML = html;
            this.attachTimeSelectHandler(); // ← ⭐️ セレクト更新後に呼ぶ
          });
      });
    }

    this.element.addEventListener("turbo:submit-end", (event) => {
      if (event.detail.success) {
        this.resetForm();
      }
    });

    // ページ初期化時にも一応ハンドラを付ける
    this.attachTimeSelectHandler();
  }

  attachTimeSelectHandler() {
    const select = this.element.querySelector("#available-time-select");
    const hidden = this.element.querySelector("#reservation_start_time");
  
    if (select && hidden) {
      select.addEventListener("change", () => {
        const dateInput = this.element.querySelector("#date-picker");
        const selectedDate = dateInput?.value; // yyyy/mm/dd
  
        if (!selectedDate) return;
  
        const time = select.value; // e.g. "10:00"
        const formatted = `${selectedDate}T${time}:00+09:00`; // ISO形式
  
        hidden.value = formatted;
      });
    }
  }
  

  resetForm() {
    const startInput = this.element.querySelector("#reservation_start_time");
    if (startInput) startInput.value = "";

    const availableTimes = this.element.querySelector("#available-times");
    if (availableTimes) {
      availableTimes.innerHTML = `
        <select class="form-select" disabled>
          <option>日付を選択してください</option>
        </select>
      `;
    }

    const datePicker = this.element.querySelector("#date-picker");
    if (datePicker) datePicker.value = "";

    const nameField = this.element.querySelector("#reservation_name");
    if (nameField) nameField.value = "";

    const noteField = this.element.querySelector("#reservation_note");
    if (noteField) noteField.value = "";

    const courseSelect = this.element.querySelector("#reservation_course");
    if (courseSelect) courseSelect.selectedIndex = 0;
  }
}
