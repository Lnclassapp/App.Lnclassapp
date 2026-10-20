# What a branch owes before it merges, and whether it already paid it (ADR-0107, chantier ci-par-train).
# bin/ci-quiet picks the level from the files the branch changed since origin/Develop:
#
#   doc    only Markdown outside the code (docs/, .claude/, the root): the guards and Rubocop, group lint
#   pr     code: lint and security, the unit tests of the touched files and of their callers, the system tests
#          bin/system-changed selects. No coverage threshold: it measures the whole suite only.
#   train  Develop, Staging, main, --full, or a change to the dependencies, the test harness or the CI (BROAD):
#          the whole bin/ci, coverage at 100 %.
#
# A green run leaves tmp/ci-verdicts/<fingerprint>-<level>. The fingerprint is the tree of the commit without its
# Markdown: a merge of Develop that brings only documents, or a fixed sentence after a review, proves nothing new.
require "digest"
require "fileutils"
require "time"

class CiScope
  LEVELS = %i[doc pr train].freeze
  TRAIN_BRANCHES = %w[Develop Staging main].freeze
  CODE_DIRS = %r{\A(app|bin|config|db|lib|script|test)/}
  # The changes a pr run cannot prove: the dependencies, the test harness and the CI itself. Everything else (a
  # migration, a fixture, a factory, a locale, a route) plays the tests that name it; what they miss, the train catches.
  BROAD = %r{
    \A(Gemfile(\.lock)?|package\.json|yarn\.lock|\.ruby-version|\.rubocop\.yml|config/ci\.rb|bin/(ci|ci-quiet|setup)\z
    |script/ci/(?!test_timings\.yml)|test/(test_helper\.rb|application_system_test_case\.rb))
  }x

  def self.doc?(path) = path.end_with?(".md") && !path.match?(CODE_DIRS)

  def self.level(branch:, changed:, full: false)
    return :train if full || TRAIN_BRANCHES.include?(branch)
    return :doc if changed.all? { doc?(it) }
    return :train if changed.any? { it.match?(BROAD) }

    :pr
  end

  # The unit tests a pr run plays: the changed test files, the mirror of each changed Ruby file (the mapping of the
  # pre-commit), and every test that names what changed: the constant of a Ruby file, the methods of a test helper
  # (test/support/), the fixture set of a fixture (`users(:`), the name of any other file, or one of its folders
  # (`docs/contenus/lecons-traitees`).
  # System tests belong to bin/system-changed.
  def self.tests_for(changed, test_files:, read: ->(path) { File.read(path) if File.exist?(path) })
    unit = test_files.reject { it.start_with?("test/system/") }
    selected = changed.select { unit.include?(it) }
    changed.grep(%r{\A(app|lib)/.+\.rb\z}).each do |file|
      relative = file.delete_prefix("app/").delete_suffix(".rb") # lib/x.rb keeps its lib/: test/lib/x_test.rb
      selected += [ "test/#{relative}_test.rb", "test/#{relative.split('/').first}/#{File.basename(relative)}_test.rb" ] & unit
    end
    names = changed.reject { doc?(it) || unit.include?(it) }.flat_map { names_of(it, read) }.uniq
    selected += unit.select { |test| read.call(test).to_s.then { |text| names.any? { text.include?(it) } } } if names.any?
    selected.uniq.sort
  end

  def self.names_of(path, read)
    return [ "#{File.basename(path, '.yml')}(:" ] if path.match?(%r{\Atest/fixtures/[^/]+\.yml\z})
    if path.end_with?(".rb")
      constant = File.basename(path, ".rb").split("_").map(&:capitalize).join
      return [ constant ] unless path.start_with?("test/support/")

      # A removed helper names nothing any more: the tests that still call it fail, and they are found by the train.
      source = read.call(path).to_s
      return [ constant ] + source.scan(/^\s*def (?:self\.)?(\w+[?!]?)/).flatten
    end

    folders = File.dirname(path).split("/")
    [ File.basename(path) ] + (2..folders.size).map { folders.first(it).join("/") }
  end

  def self.fingerprint(ls_tree)
    kept = ls_tree.lines.map(&:chomp).reject { doc?(it.split("\t", 2).last.to_s) }
    Digest::SHA256.hexdigest(kept.join("\n"))
  end

  # The green verdicts of this machine, one file per fingerprint and level.
  class Verdicts
    def initialize(dir) = @dir = dir

    # A level proves the levels below it: a green train covers a pr and a doc.
    def find(fingerprint, level)
      LEVELS.drop(LEVELS.index(level)).reverse_each do |proven|
        path = File.join(@dir, "#{fingerprint}-#{proven}")
        return File.read(path).strip if File.exist?(path)
      end
      nil
    end

    def record(fingerprint, level, line)
      FileUtils.mkdir_p(@dir)
      File.write(File.join(@dir, "#{fingerprint}-#{level}"), "#{line}\n")
    end
  end
end
