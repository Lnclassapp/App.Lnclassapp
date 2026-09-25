# Fragment caching is off in test; a test that proves a cache key turns it on for its block only.
# The store is :memory_store, emptied before every test (test_helper).
module CachingHelper
  ActiveSupport::TestCase.include(self)

  def with_fragment_caching
    previous = ActionController::Base.perform_caching
    ActionController::Base.perform_caching = true
    yield
  ensure
    ActionController::Base.perform_caching = previous
  end
end
