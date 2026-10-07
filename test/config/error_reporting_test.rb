require "test_helper"

# config/initializers/error_reporting.rb — Rails.error had no subscriber: an error reported as handled (rescued so that
# the page goes on, like the blog's read counter, ADR-0074 §4.7) vanished in production. It is now logged. An unhandled
# error is already logged by Rails (ActionDispatch::DebugExceptions, Active Job), so it is not logged a second time.
class ErrorReportingTest < ActiveSupport::TestCase
  def logged
    io = StringIO.new
    logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = logger
  end

  test "a handled error is logged at error level, with its class, message, severity, source and context" do
    output = logged do
      Rails.error.report(ActiveRecord::ConnectionTimeoutError.new("pool épuisé"), handled: true, context: { article_id: 42 })
    end

    assert_match(/ActiveRecord::ConnectionTimeoutError: pool épuisé/, output)
    assert_match(/handled: true/, output)
    assert_match(/severity: warning/, output)
    assert_match(/source: application/, output)
    assert_match(/article_id: 42|:article_id=>42|"article_id" ?=> ?42/, output)
  end

  test "an unhandled error is left to the log Rails already writes for it" do
    output = logged { Rails.error.report(RuntimeError.new("déjà journalisée"), handled: false) }

    assert_empty output
  end

  test "the subscriber is registered once, on boot" do
    subscribers = Rails.error.instance_variable_get(:@subscribers)

    assert_equal 1, subscribers.count { it.is_a?(ErrorReporting::LogSubscriber) }
  end
end
