# The steps of bin/ci, declared once in config/ci.rb and grouped so that GitHub can run the groups side by side
# (chantier ci-rapide). CI_GROUP picks what one runner plays:
#
#   (unset)          every group, in declaration order: what bin/ci has always done locally
#   lint,assets      several groups in one run
#   system:2/4       the second of four parts of a sharded group
#
# A sharded group splits its test files into parts of similar duration, from the timings in
# script/ci/test_timings.yml (longest file first, into the lightest part). The split is deterministic:
# the same files and timings always give the same parts, on every runner.
require "yaml"

class CiPlan
  Step = Data.define(:group, :title, :command)
  Group = Data.define(:name, :db, :files)

  ROOT = File.expand_path("../..", __dir__)
  TIMINGS = File.join(__dir__, "test_timings.yml")

  class SelectionError < StandardError; end

  attr_reader :groups

  def self.define(&) = new.tap { it.instance_eval(&) }

  def initialize
    @groups = {}
    @declarations = []
  end

  # A group of steps. `db: true` when one of its steps needs PostgreSQL: bin/setup then prepares the database.
  def group(name, db: false, &block)
    add_group(Group.new(name:, db:, files: nil), block)
  end

  # A group whose block receives the files of its part (every file when the run is not split) and the part label.
  def sharded(name, files:, db: true, &block)
    add_group(Group.new(name:, db:, files: files.sort), block)
  end

  def step(title, command)
    @steps << Step.new(group: @current, title:, command:)
  end

  # The steps one runner plays for CI_GROUP, Setup first.
  def steps_for(selection)
    picks = parse(selection)
    setup = Step.new(group: nil, title: "Setup", command: setup_command(picks.map(&:first)))
    [ setup, *picks.flat_map { |group, part, parts| expand(group, part, parts) } ]
  end

  # The files of each part of a sharded group, balanced on the recorded durations.
  def split(name, parts, timings: self.class.timings)
    files = @groups.fetch(name).files
    known = files.filter_map { timings[it] }.sort
    default = known.empty? ? 1.0 : known[known.size / 2]
    buckets = Array.new(parts) { [ 0.0, [] ] }

    files.sort_by { [ -timings.fetch(it, default), it ] }.each do |file|
      bucket = buckets.min_by.with_index { |(total, _), index| [ total, index ] }
      bucket[0] += timings.fetch(file, default)
      bucket[1] << file
    end

    buckets.map { |_, chosen| chosen.sort }
  end

  # The files matching a glob, relative to the root of the repository, whatever the current directory.
  def self.files(glob) = Dir[File.join(ROOT, glob)].map { it.delete_prefix("#{ROOT}/") }

  def self.timings
    File.exist?(TIMINGS) ? YAML.safe_load_file(TIMINGS) || {} : {}
  end

  private

  def add_group(group, block)
    raise ArgumentError, "group #{group.name} declared twice" if @groups.key?(group.name)

    @groups[group.name] = group
    @declarations << [ group, block ]
  end

  # Unset: every group, whole. Otherwise a comma-separated list of `name` or `name:k/n`.
  def parse(selection)
    return @groups.values.map { [ it, 1, 1 ] } if selection.to_s.strip.empty?

    picks = selection.split(",").map(&:strip).map do |token|
      name, part, parts = token.match(/\A([a-z]+)(?::(\d+)\/(\d+))?\z/)&.captures
      group = @groups[name] or raise SelectionError, "CI_GROUP : groupe inconnu « #{token} » (connus : #{@groups.keys.join(', ')})"
      part, parts = (part ? [ part.to_i, parts.to_i ] : [ 1, 1 ])
      raise SelectionError, "CI_GROUP : part invalide « #{token} »" unless parts.positive? && part.between?(1, parts)
      raise SelectionError, "CI_GROUP : « #{name} » n'est pas découpé en parts" if parts > 1 && group.files.nil?

      [ group, part, parts ]
    end
    # Declaration order, whatever the order of CI_GROUP: a group's steps keep their place in the full run.
    picks.sort_by { |group, part, _| [ @groups.keys.index(group.name), part ] }
  end

  def expand(group, part, parts)
    @steps = []
    @current = group.name
    _, block = @declarations.find { |declared, _| declared == group }
    if group.files
      files = parts == 1 ? group.files : split(group.name, parts)[part - 1]
      instance_exec(files, parts == 1 ? nil : "#{part}/#{parts}", &block)
    else
      instance_eval(&block)
    end
    @steps
  end

  def setup_command(groups)
    groups.any?(&:db) ? "bin/setup --skip-server" : "bin/setup --skip-server --skip-db"
  end
end
