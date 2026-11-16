# In-memory PushSubscriptionRepositoryPort: the subscriptions a user holds, and the session ids whose subscriptions were deleted.
class FakePushSubscriptions
  include Ports::Communication::PushSubscriptionRepositoryPort

  attr_reader :deleted_sessions, :reattached, :kept_session, :deleted_users

  def initialize(*subscriptions) = (@subscriptions, @deleted_sessions, @deleted_users = subscriptions, [], [])
  def for_user(user_id:) = @subscriptions.select { it.user_id == user_id }
  def delete_for_user(user_id:) = (@deleted_users << user_id).size
  def reattach_session(from_session_id:, to_session_id:) = (@reattached = [ from_session_id, to_session_id ]).size

  def delete_for_user_except_session(user_id:, session_id:)
    @kept_session = session_id
    @subscriptions.reject! { it.user_id == user_id && it.session_id != session_id }
    1
  end

  def delete_for_sessions(session_ids:) = @deleted_sessions << session_ids

  def self.subscription(user_id:, session_id:)
    Entities::Communication::PushSubscription.new(user_id:, session_id:, endpoint: "https://fcm.googleapis.com/fcm/send/#{session_id}", p256dh: "k", auth: "a")
  end
end
