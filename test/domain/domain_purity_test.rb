# Pure Ruby on purpose: the pre-commit runs it with `ruby -Itest`, without Rails
# nor a database (~0.3 s). Under `bin/rails test` it runs like any other test.
require "minitest/autorun"
require "tmpdir"

# Golden rule 1 (CLAUDE.md, ADR-0001): the domain never reaches the infrastructure.
class DomainPurityTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  FORBIDDEN = /\b(ActiveRecord|ApplicationRecord|Orm::|Repositories::|Queries::|ActiveStorage|ActionController|ActionDispatch)/

  def self.offenses_in(files)
    files.flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, index|
        next if line.lstrip.start_with?("#")

        "#{file.delete_prefix("#{ROOT}/")}:#{index + 1}: #{line.strip}" if line.match?(FORBIDDEN)
      end
    end
  end

  def test_the_domain_never_references_the_infrastructure
    offenses = self.class.offenses_in(Dir[File.join(ROOT, "app/domain/**/*.rb")])

    assert_empty offenses, <<~MSG
      app/domain/ doit rester du Ruby pur : ni ActiveRecord, ni ApplicationRecord, ni Orm::,
      ni Repositories::, ni Queries::, ni ActiveStorage, ActionController ou ActionDispatch.
      Passe par un port (app/domain/ports/).
      #{offenses.join("\n")}
    MSG
  end

  def test_the_scan_catches_every_forbidden_reference
    Dir.mktmpdir do |dir|
      dirty = File.join(dir, "dirty.rb")
      File.write(dirty, <<~RUBY)
        # Orm::Course in a comment is tolerated
        Orm::Course.find(1)
        ActiveRecord::Base
        ApplicationRecord
        Repositories::Catalog::CourseRepository.new
        Queries::School::EngagementQuery.new
        ActiveStorage::Blob.find(1)
        ActionController::Parameters.new
        ActionDispatch::Http::UploadedFile
      RUBY

      assert_equal 8, self.class.offenses_in([ dirty ]).size
    end
  end
end
