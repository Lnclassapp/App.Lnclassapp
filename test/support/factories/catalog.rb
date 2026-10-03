require Rails.root.join("db/migrate/20260928140100_fill_classroom_plan_entries").to_s

# Referential, content and import reports (ADR-0034, ADR-0035, ADR-0039), and the barème of the classrooms (ADR-0058).
module Factories
  module Catalog
    ActiveSupport::TestCase.include(self)

    # The development seed referential (ADR-0034): 7 levels, 5 series, 10 pairs, 6 materials (Anglais removed by the owner, 2026-10-03).
    LEVELS = [ [ "6ème", "first" ], [ "5ème", "first" ], [ "4ème", "first" ], [ "3ème", "first" ],
               [ "2nde", "second" ], [ "1ère", "second" ], [ "Tle", "second" ] ].freeze
    SERIES_BY_LEVEL = { "2nde" => %w[A C], "1ère" => %w[A1 A2 C D], "Tle" => %w[A1 A2 C D] }.freeze
    MATERIALS = [ [ "Mathématiques", "Maths", "science" ], [ "Physique-Chimie", "PC", "science" ], [ "SVT", "SVT", "science" ],
                  [ "Français", "Français", "literature" ],
                  [ "Histoire-Géographie", "HG", "literature" ], [ "Philosophie", "Philo", "literature" ] ].freeze

    def create_level(name: nil, position: nil, cycle: "second")
      sequence = factory_sequence
      Orm::Level.create!(name: name || "Niveau #{sequence}", position: position || 100 + sequence, cycle:)
    end

    def create_series(name: "S#{factory_sequence}")
      Orm::Series.create!(name:)
    end

    def link_level_series(level: create_level, series: create_series)
      Orm::LevelSeries.create!(level:, series:)
    end

    def create_material(name: nil, category: "science", shortname: nil)
      sequence = factory_sequence
      Orm::Material.create!(name: name || "Matière #{sequence}", shortname: shortname || "M#{sequence}", category:)
    end

    def create_course(level: create_level, material: create_material, series: nil, name: "Cours #{factory_sequence}",
                      author: create_team_member(team_role: "content", second_factor: false), status: "published",
                      content: "<p>Contenu du cours.</p>", **attributes)
      Orm::Course.create!(level:, material:, series:, name:, author:, content:, **factory_publication(status), **attributes)
    end

    def create_essential(course: create_course, name: "Fiche #{factory_sequence}", position: nil, status: "published",
                         content: "<p>L'essentiel à retenir.</p>", author: course.author, **attributes)
      position ||= course.essentials.maximum(:position).to_i + 1
      Orm::Essential.create!(course:, name:, position:, content:, author:, **factory_publication(status), **attributes)
    end

    # Returns { levels:, series:, materials: }, each indexed by slug.
    def seed_referential
      levels = LEVELS.each_with_index.to_h { |(name, cycle), index| [ name, create_level(name:, position: index + 1, cycle:) ] }
      series = SERIES_BY_LEVEL.values.flatten.uniq.to_h { |name| [ name, create_series(name:) ] }
      SERIES_BY_LEVEL.each { |level, names| names.each { |name| link_level_series(level: levels[level], series: series[name]) } }
      materials = MATERIALS.map { |name, shortname, category| create_material(name:, shortname:, category:) }
      seed_classroom_plan

      { levels: levels.values.index_by(&:slug), series: series.values.index_by(&:slug), materials: materials.index_by(&:slug) }
    end

    # The old barème taken over on the referential in base, exactly as the deployment did (ADR-0058).
    def seed_classroom_plan = FillClassroomPlanEntries.fill

    def create_import_report(kind: "schools", status: "queued", imported_by: create_team_member(second_factor: false),
                             checksum_sha256: SecureRandom.hex(32), **attributes)
      Orm::ImportReport.create!(kind:, status:, imported_by:, checksum_sha256:, **attributes)
    end

    # status, published_at and archived_at move together on every piece of content (ADR-0035).
    def factory_publication(status)
      { status:, published_at: (Time.current if status != "draft"), archived_at: (Time.current if status == "archived") }
    end
  end
end
