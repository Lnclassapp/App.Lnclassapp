# Loaded by RUBYOPT before anything else when script/ci/record_system_map draws the map of the system tests
# (chantier ci-scope-tests-systeme): line coverage must run before the application loads, or the files loaded at boot
# (eager_load, CI=true) never count. Nothing else: no gem is loaded here, Bundler has not run yet.
require "coverage"
Coverage.start(lines: true) unless Coverage.running?
