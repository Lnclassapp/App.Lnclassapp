# The pilot flags (config/initializers/pilot_flags.rb) are off in test as in production; a test that needs one on turns it
# on with pilot_flags!, and every test ends with the flags read at boot.
module PilotFlagsHelper
  BOOT = Rails.configuration.x.pilot_flags

  ActiveSupport::TestCase.include(self)
  ActiveSupport::TestCase.teardown { Rails.configuration.x.pilot_flags = BOOT }

  def pilot_flags!(**flags)
    Rails.configuration.x.pilot_flags = Rails.configuration.x.pilot_flags.merge(flags).freeze
  end
end
