require "test_helper"

module Entities
  module Identity
    class BackupCodesTest < ActiveSupport::TestCase
      test "génère 10 codes distincts de 10 caractères base58" do
        codes = BackupCodes.generate

        assert_equal 10, codes.size
        assert_equal 10, codes.uniq.size
        codes.each { |code| assert_match(/\A[1-9A-HJ-NP-Za-km-z]{10}\z/, code) }
      end
    end
  end
end
