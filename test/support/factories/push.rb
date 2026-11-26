# Web Push subscriptions, preferences and deliveries (notifications-push, ADR-0146 §4.1), motive settings and approvals
# (parametrage-notifications, ADR XXXX §4.1),
# written as the repositories write them. Shared by every lot of the chantier.
module Factories
  module Push
    ActiveSupport::TestCase.include(self)

    def create_push_subscription(user: create_student, session: nil, endpoint: "https://fcm.googleapis.com/fcm/send/#{SecureRandom.hex(8)}",
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

    def create_push_motive_setting(motive: "assignment_due", automatic: true, updated_by: create_team_member, updated_at: Time.current, **attributes)
      Orm::Communication::PushMotiveSetting.create!(motive:, automatic:, updated_by:, updated_at:, **attributes)
    end

    # recipients : [[user_id, object_key], …] ; recipients_count suit la liste sauf si l'appelant le force.
    def create_push_approval(motive: "inactive", on_date: Date.current, approved_by: create_team_member, approved_at: Time.current, recipients: [], **attributes)
      approval = Orm::Communication::PushApproval.create!(motive:, on_date:, approved_by:, approved_at:,
                                                          recipients_count: attributes.delete(:recipients_count) || recipients.size, **attributes)
      recipients.each { |user_id, object_key| approval.recipients.create!(user_id:, object_key:) }
      approval
    end
  end
end
