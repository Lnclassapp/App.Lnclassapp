require "test_helper"

# ADR-0147, amendement du 2026-11-27 (II) : un événement demande un passage d'envoi ; la file indisponible ne lève pas.
module Gateways
  module Communication
    class PushPassTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      test "enfile un passage d'envoi" do
        assert_enqueued_with(job: ::Communication::DeliverPushNotificationsJob) { assert_nil PushPass.new.request }
      end

      test "dans une transaction, enfilé au commit seulement ; une transaction annulée n'enfile rien" do
        ActiveRecord::Base.transaction(requires_new: true) do
          PushPass.new.request
          assert_no_enqueued_jobs
        end
        assert_enqueued_jobs 1

        clear_enqueued_jobs
        ActiveRecord::Base.transaction(requires_new: true) do
          PushPass.new.request
          raise ActiveRecord::Rollback
        end
        assert_no_enqueued_jobs
      end

      test "une file indisponible est signalée, jamais levée" do
        reported = []
        failing = ->(*) { raise ActiveJob::EnqueueError, "file indisponible" }
        stub_method(::Communication::DeliverPushNotificationsJob, :perform_later, failing) do
          stub_method(Rails.error, :report, ->(error, **) { reported << error.class }) { assert_nil PushPass.new.request }
        end

        assert_equal [ ActiveJob::EnqueueError ], reported
      end

      test "le port seul refuse d'être appelé" do
        assert_raises(NotImplementedError) { Class.new { include Ports::Communication::PushPassPort }.new.request }
      end
    end
  end
end
