require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  class PingMailer < ApplicationMailer
    def ping
      mail(to: "someone@example.com", subject: "ping") { |format| format.text { render plain: "pong" } }
    end
  end

  test "a mail built on ApplicationMailer uses the default sender" do
    email = PingMailer.ping

    assert_emails(1) { email.deliver_now }
    assert_equal [ "from@example.com" ], email.from
    assert_equal "pong", email.body.to_s.strip
  end
end
