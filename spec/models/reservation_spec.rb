require 'rails_helper'

RSpec.describe Reservation, type: :model do
  describe 'validations' do
    it 'requires start_time and end_time' do
      reservation = Reservation.new
      expect(reservation).not_to be_valid
      expect(reservation.errors[:start_time]).to include("can't be blank")
    end
  end

  describe '#cancel!' do
    let(:reservation) { create(:reservation, status: :confirmed) }

    it 'cancels the reservation' do
      reservation.cancel!('テスト理由')
      expect(reservation.status).to eq('cancelled')
      expect(reservation.cancellation_reason).to eq('テスト理由')
    end
  end
end