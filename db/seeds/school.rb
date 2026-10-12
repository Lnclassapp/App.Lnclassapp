# ADR-0034, ADR-0030, ADR-0058: the 41 DRENA, then four schools of Abidjan 2 with their generated classrooms — a public
# lycée (77), a private one (38), a mixed one (38) and a public collège (28). Idempotent by slug and by name.
# Never in production: the team creates the DRENA on screen and imports the schools (ADR-0039).
raise "db/seeds/school.rb est réservé au développement et au test" unless Rails.env.local?

YAML.load_file(Rails.root.join("db/seeds/data/drenas.yml")).each do |name|
  Orm::Drena.create!(name:) unless Orm::Drena.exists?(slug: Entities::School::Drena.slug_for(name))
end

drena = Orm::Drena.find_by!(slug: "drena-abidjan-2")
schools = [ [ "Lycée Moderne de Treichville", "LMT", "public", "both" ], [ "Lycée privé Les Lauriers", "LPL", "private", "both" ],
            [ "Lycée mixte La Réussite", "LMR", "mixed", "both" ], [ "Collège Moderne de Marcory", "CMM", "public", "first" ] ]
existing = Orm::School.where(drena:).pluck(:name)
missing = schools.reject { |name, *| existing.include?(name) }
# ADR-0057: each school gets its school code, drawn by the domain as the import does.
school_codes = Entities::School::SchoolCode.generate_unique(count: missing.size,
                                                           taken: Repositories::School::SchoolRepository.new.taken_school_codes)
rows = missing.zip(school_codes).map do |(name, sigle, school_type, cycle), school_code|
  { public_id: SecureRandom.base58(14), drena_id: drena.id, name:, sigle:, school_type:, cycle:, status: "active", school_code: }
end

now = Time.current
school_year = Entities::Classroom::SchoolYear.current(now.to_date)
classrooms = Repositories::Classroom::ClassroomRepository.new
lookup = Repositories::Catalog::TaxonomyRepository.new.lookup
plan = Repositories::Classroom::ClassroomPlanRepository.new.plan
Orm::School.transaction do
  Repositories::School::SchoolRepository.new.insert_many(rows:, at: now).each do |school|
    generated = Entities::Classroom::DefaultClassroomPlan.rows_for(school:, lookup:, plan:).rows
    classroom_rows = generated.map do |row|
      row.merge(public_id: SecureRandom.base58(14), school_id: school.id, school_year:)
    end
    classrooms.insert_generated(rows: classroom_rows, at: now)
  end
end
