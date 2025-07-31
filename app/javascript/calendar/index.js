import initializeCalendar from './calendar_core';
import setupReservationModal from './modal_controller';
import setupIntervalControls from './interval_settings';
import setupReservationForm from './reservation_form';
import setupGlobalUtils from './utils';

document.addEventListener('turbo:load', () => {
  setupGlobalUtils();
  initializeCalendar();
  setupReservationModal();
  setupIntervalControls();
  setupReservationForm();
});
