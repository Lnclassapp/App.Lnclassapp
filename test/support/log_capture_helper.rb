# What the block writes to Rails.logger, as a string: proves that a deletion or a refusal leaves a trace.
module LogCaptureHelper
  ActiveSupport::TestCase.include(self)

  def capture_log
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    Rails.logger.broadcast_to(logger)
    yield
    io.string
  ensure
    Rails.logger.stop_broadcasting_to(logger)
  end
end
