# A counter shared by every factory, so that each default value is unique within a test.
# Parallel workers are forked processes: each one counts on its own, in its own database.
module Factories
  module Sequence
    ActiveSupport::TestCase.include(self)

    @count = 0

    def self.next = @count += 1

    def factory_sequence = Sequence.next
  end
end
