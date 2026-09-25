require "test_helper"

module Repositories
  module Shared
    class TransactionTest < ActiveSupport::TestCase
      setup { @transaction = Transaction.new }

      test "call returns the value of the block" do
        assert_equal 42, @transaction.call { 42 }
      end

      test "call rolls everything back on an exception and lets it through" do
        assert_raises(RuntimeError) do
          @transaction.call do
            create_drena(name: "DRENA Abidjan 1")
            raise "boom"
          end
        end

        assert_not Orm::Drena.exists?(name: "DRENA Abidjan 1")
      end

      test "attempt wraps the value of the block in a success" do
        result = @transaction.attempt { :written }

        assert result.success?
        assert_equal :written, result.value
      end

      test "attempt turns a unique index violation into a conflict and rolls back" do
        create_drena(name: "DRENA Bouaké")

        result = @transaction.attempt do
          create_drena(name: "DRENA Korhogo")
          Orm::Drena.insert_all!([ { name: "DRENA Bouaké", public_id: SecureRandom.base58(14), slug: "drena-bouake",
                                     created_at: Time.current, updated_at: Time.current } ])
        end

        assert_equal :conflict, result.code
        assert_equal({ base: [ :write_failed ] }, result.errors)
        assert_not Orm::Drena.exists?(name: "DRENA Korhogo")
      end

      test "attempt turns a failed validation into a conflict" do
        result = @transaction.attempt { Orm::Drena.create!(name: nil) }

        assert_equal :conflict, result.code
      end

      test "attempt lets any other exception through" do
        assert_raises(ArgumentError) { @transaction.attempt { raise ArgumentError } }
      end
    end
  end
end
