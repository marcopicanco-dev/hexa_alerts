require "test_helper"

class AlertSubscriptionTest < ActiveSupport::TestCase
  test "requires a team or a match" do
    subscription = AlertSubscription.new(fan: Fan.new(name: "Ana", email: "ana@example.com"))

    assert_not subscription.valid?
    assert_includes subscription.errors[:base], "choose a team or match"
  end
end
