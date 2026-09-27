require "test_helper"

# ADR-0026, ADR-0027, ADR-0039: every file lives in its bounded context, the former layers are gone, no model
# outside ApplicationRecord, no find_or_create_by (a race, and a write outside the use case) and no import file
# written under tmp/.
class LayoutTest < ActiveSupport::TestCase
  NAMESPACED = %w[app/domain/entities app/domain/use_cases app/domain/ports app/domain/dtos app/domain/policies
                  app/infrastructure/repositories app/infrastructure/queries].freeze
  GONE = %w[app/presentation app/services app/infrastructure/adapters].freeze

  def root = Rails.root

  test "no file sits at the root of a layer folder" do
    offenders = NAMESPACED.flat_map { |folder| root.glob("#{folder}/*").select(&:file?) }

    assert_empty offenders.map { it.relative_path_from(root).to_s }
  end

  test "the former layers are gone" do
    assert_empty GONE.select { root.join(it).exist? }
  end

  test "app/models holds ApplicationRecord alone" do
    files = root.glob("app/models/**/*").select(&:file?).map { it.relative_path_from(root).to_s }

    assert_equal [ "app/models/application_record.rb" ], files - [ "app/models/concerns/.keep" ]
  end

  test "no find_or_create_by and no tmp/imports in app/" do
    offenders = root.glob("app/**/*.{rb,erb}").select { it.read.match?(/find_or_create_by|tmp\/imports/) }

    assert_empty offenders.map { it.relative_path_from(root).to_s }
  end
end
