# Web Push subscriptions, preferences and deliveries (notifications-push, ADR-XXXX-notifications-web-push-aux-eleves §4.1),
# written as the repositories write them. Shared by every lot of the chantier.
module Factories
  module Push
    ActiveSupport::TestCase.include(self)

    def create_push_subscription(user: create_student, session: nil, endpoint: "https://push.example.test/send/#{SecureRandom.hex(8)}",
                                 p256dh: "BP#{SecureRandom.urlsafe_base64(60)}", auth: SecureRandom.urlsafe_base64(16), **attributes)
      Orm::Communication::PushSubscription.create!(user:, session:, endpoint:, p256dh:, auth:, **attributes)
    end

    def create_push_preference(user: create_student, **attributes)
      Orm::Communication::PushPreference.create!(user:, **attributes)
    end

    def create_push_delivery(user: create_student, motive: "inactive", object_key: "inactive:#{SecureRandom.hex(4)}", status: "delivered",
                             sent_at: Time.current, **attributes)
      Orm::Communication::PushDelivery.create!(user:, motive:, object_key:, status:, sent_at:, **attributes)
    end
  end
end
