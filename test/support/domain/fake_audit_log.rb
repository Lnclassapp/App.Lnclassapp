# In-memory AuditLogPort: the events a use case records, in order.
class FakeAuditLog
  include Ports::Identity::AuditLogPort

  attr_reader :events

  def initialize = @events = []
  def record(**event) = (@events << event) && true
end
