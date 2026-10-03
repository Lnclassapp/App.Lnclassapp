require "test_helper"

# ADR-0072 §4.1: only an exercise can be assigned. No file of app/ passes "Course" or "Essential" as an assignable type:
# not to a toggle (assignable_type:), nor to a query (where(assignable_type: …), [type, id] keys), nor to the domain
# (Assignable.new(type: …), when "Course"). The only remaining literals name the subject of an audit event.
class AssignableTypesTest < ActiveSupport::TestCase
  LITERAL = /["'](?:Course|Essential)["']/
  # The audit log names the content it records (ADR-0035): it is not an assignment.
  ALLOWED = /subject_type:\s*\z/

  def root = Rails.root

  test "Assignable::TYPES holds Exercise alone" do
    assert_equal %w[Exercise], Entities::Classroom::Assignable::TYPES
  end

  test "no Course or Essential literal in app/ outside the subject of an audit event" do
    offenders = root.glob("app/**/*.{rb,erb}").flat_map do |file|
      file.each_line.with_index(1).flat_map do |line, number|
        line.to_enum(:scan, LITERAL).filter_map do
          match = Regexp.last_match
          "#{file.relative_path_from(root)}:#{number}: #{line.strip}" unless match.pre_match.match?(ALLOWED)
        end
      end
    end

    assert_empty offenders
  end

  test "no %w list of app/ names Course or Essential as an assignable type" do
    offenders = root.glob("app/**/*.{rb,erb}").select { it.read.match?(/%w\[[^\]]*\b(?:Course|Essential)\b[^\]]*\]/) }

    assert_empty offenders.map { it.relative_path_from(root).to_s }
  end
end
