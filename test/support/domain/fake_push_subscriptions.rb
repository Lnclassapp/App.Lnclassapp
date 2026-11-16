# In-memory PushSubscriptionRepositoryPort: the subscriptions a user holds, and the session ids whose subscriptions were deleted.
class FakePushSubscriptions
  include Ports::Communication::PushSubscriptionRepositoryPort

  attr_reader :deleted_sessions

  def initialize(*subscriptions) = (@subscriptions, @deleted_sessions = subscriptions, [])
  def for_user(user_id:) = @subscriptions.select { it.user_id == user_id }
  def delete_for_sessions(session_ids:) = @deleted_sessions << session_ids

  def self.subscription(user_id:, session_id:)
    Entities::Communication::PushSubscription.new(user_id:, session_id:, endpoint: "https://push.example.test/#{session_id}", p256dh: "k", auth: "a")
  end
end
