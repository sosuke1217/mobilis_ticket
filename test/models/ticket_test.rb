require "test_helper"

class TicketTest < ActiveSupport::TestCase
  test "unit_price returns float when division is not even" do
    template = TicketTemplate.new(price: 10, total_count: 3)
    ticket = Ticket.new(ticket_template: template)

    assert_in_delta 3.33, ticket.unit_price, 0.01
  end
end
