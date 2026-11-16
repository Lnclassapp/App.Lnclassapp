require "test_helper"

module Queries
  module Communication
    class PushCandidatesTest < ActiveSupport::TestCase
      test "les six requêtes sont vides tant que leur lot ne les remplit pas, et le composite les réunit" do
        assert_equal 6, PushCandidates::SOURCES.size
        PushCandidates::SOURCES.each { assert_equal [], it.new.for(now: Time.current) }
        assert_equal [], PushCandidates.new.for(now: Time.current)
      end

      test "le composite concatène ses sources" do
        source = Struct.new(:items) { def for(now:) = items }

        assert_equal %i[a b c], PushCandidates.new(sources: [ source.new(%i[a b]), source.new([]), source.new(%i[c]) ]).for(now: Time.current)
      end
    end
  end
end
