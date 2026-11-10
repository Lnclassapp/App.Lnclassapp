# The map of the system tests (chantier ci-scope-tests-systeme, ADR-0127): with SYSTEM_MAP=<dir>, each system test
# notes the application files it ran (Ruby lines run, templates and partials rendered) and each process writes
# <dir>/<pid>.json at exit. script/ci/record_system_map draws it and folds it into script/ci/system_map.yml, which
# bin/system-changed reads. Loaded by test/support/system_map.rb only under SYSTEM_MAP.
require "coverage"
require "json"

module SystemMapRecorder
  ROOT = Rails.root.to_s + "/"
  # What a change can break in the browser: the code the application runs, not the tests nor the gems.
  APP = %r{\A(app|lib|config)/}

  class << self
    attr_reader :map

    def start(dir)
      abort "SYSTEM_MAP : la couverture doit démarrer avant l'application (script/ci/record_system_map)." unless Coverage.running?
      @dir = dir
      @map = Hash.new { |hash, key| hash[key] = Set.new }
      @rendered = Set.new
      ActiveSupport::Notifications.subscribe(/\Arender_(template|partial|collection|layout)\.action_view\z/) do |*, payload|
        @rendered << payload[:identifier].to_s
      end
      at_exit { write }
    end

    def reset
      Coverage.result(stop: false, clear: true)
      @rendered.clear
    end

    def record(test_file)
      ran = Coverage.result(stop: false, clear: true).filter_map { |path, counts| path if counts[:lines]&.any? { it.to_i.positive? } }
      (ran + @rendered.to_a).each do |path|
        relative = path.delete_prefix(ROOT)
        @map[test_file] << relative if relative != path && relative.match?(APP)
      end
      @rendered.clear
    end

    def write
      return if @map.empty?

      FileUtils.mkdir_p(@dir)
      File.write(File.join(@dir, "#{Process.pid}.json"), JSON.generate(@map.transform_values { it.to_a.sort }))
    end
  end

  # Prepended to the system tests: the files one test runs, from its setup to its teardown, belong to its file.
  module Hooks
    def before_setup
      SystemMapRecorder.reset
      super
    end

    def after_teardown
      super
    ensure
      file = method(name).source_location.first.delete_prefix(SystemMapRecorder::ROOT)
      SystemMapRecorder.record(file)
    end
  end
end

SystemMapRecorder.start(ENV.fetch("SYSTEM_MAP"))
ActiveSupport.on_load(:action_dispatch_system_test_case) { prepend SystemMapRecorder::Hooks }
