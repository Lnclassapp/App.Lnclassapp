require "test_helper"

# ADR-XXXX-notifications-web-push-aux-eleves §4.1 : ce que la base impose.
class PushTablesTest < ActiveSupport::TestCase
  test "les trois fabriques écrivent une ligne valide" do
    assert create_push_subscription.persisted?
    assert create_push_preference.persisted?
    assert create_push_delivery.persisted?
  end

  test "une adresse d'abonnement est unique" do
    first = create_push_subscription
    assert_raises(ActiveRecord::RecordInvalid) { create_push_subscription(endpoint: first.endpoint) }
    assert_raises(ActiveRecord::RecordInvalid) { create_push_subscription(endpoint: nil) }
  end

  test "supprimer la session garde l'abonnement, qui perd sa session" do
    session = create_login_session
    subscription = create_push_subscription(user: session.user, session:)

    session.destroy!

    assert_nil subscription.reload.session_id
  end

  test "une préférence par élève" do
    preference = create_push_preference
    assert_raises(ActiveRecord::RecordInvalid) { create_push_preference(user: preference.user) }
  end

  test "un envoi est unique par élève, motif et clé d'objet" do
    delivery = create_push_delivery
    assert_raises(ActiveRecord::RecordNotUnique) { create_push_delivery(user: delivery.user, motive: delivery.motive, object_key: delivery.object_key) }
    assert_raises(ActiveRecord::StatementInvalid) { create_push_delivery(motive: "promo") }
    assert_raises(ActiveRecord::StatementInvalid) { create_push_delivery(status: "sent") }
    assert_raises(ActiveRecord::RecordInvalid) { create_push_delivery(object_key: nil) }
  end
end
