require "test_helper"

# ADR standard-de-test §7 : le vrai manifeste, contre le vrai dossier des leçons traitées.
class StandardManifestTest < ActiveSupport::TestCase
  SEEDS = Rails.root.join("db/seeds/standard")
  LESSONS = Rails.root.join("docs/contenus/lecons-traitees")
  PRD_COUPLES = 63

  setup do
    @manifest = YAML.load_file(SEEDS.join("jeu.yml"))
    @names = YAML.load_file(SEEDS.join("noms.yml"))
    @set = Entities::Catalog::StandardTestSet.new(@manifest)
    @identity = Entities::School::FictitiousIdentity.new(@names)
  end

  def repository_files
    LESSONS.glob("*/*/*.json").to_h do |path|
      [ path.relative_path_from(LESSONS).to_s, JSON.parse(path.read)["version"] ]
    end
  end

  test "the manifest is valid against the repository: every file exists and is v3, no couple with v3 is forgotten" do
    assert_empty @set.errors(repository_files).map(&:message)
  end

  test "one v3 file per couple (63: the 3eme base, the 4eme base, 5ème mathematics and physics-chemistry, 1ère A1, A2, C, D and history-geography, 2nde A, C and history-geography, Tle C, Tle D, Tle A1, Tle A2 and Tle history-geography) and the longest lesson, the biggest v3 file of the repository" do
    assert_equal PRD_COUPLES, @set.lessons.size
    v3 = LESSONS.glob("*/*/*.json").select { JSON.parse(it.read)["version"] == 3 }
    assert_equal v3.max_by(&:size).relative_path_from(LESSONS).to_s, @set.longest
  end

  test "the couples without v3 are written empty and have no v3 file" do
    assert_empty @set.without_v3
    @set.without_v3.each { assert_not_includes @set.lessons.keys, it }
  end

  test "three schools: a public lycee, a private college and a mixed large one on two existing DRENAs" do
    assert_equal [ %w[lycee public both], %w[college private first], %w[grand mixed both] ], @set.schools.map { [ it.key, it.type, it.cycle ] }
    assert_equal 1500, @set.school("grand").students
    drenas = YAML.load_file(Rails.root.join("db/seeds/data/drenas.yml"))
    assert_empty @set.schools.map(&:drena).uniq - drenas
    assert_equal 2, @set.schools.map(&:drena).uniq.size
  end

  test "the lycee has a class per level and series from 6eme to Tle, series A1 A2 C D in 1ere and Tle, A and C in 2nde" do
    keys = @set.classrooms_of("lycee").map(&:key)
    assert_equal %w[6eme 5eme 4eme 3eme 2nde-a 2nde-c 1ere-a1 1ere-a2 1ere-c 1ere-d tle-a1 tle-a2 tle-c tle-d], keys
    assert_equal %w[6eme 5eme 4eme 3eme], @set.classrooms_of("college").map(&:key)
  end

  test "the hard cases exist in the manifest" do
    cases = @set.cases
    assert_equal "college/5eme", cases.empty_classroom
    assert_equal "lycee/tle-a1", cases.student_without_activity
    assert_equal "lycee/tle-d", cases.full_classroom
    assert_equal 40, cases.full_classroom_size
    classroom_keys = @set.classrooms.map { "#{it.school}/#{it.key}" }
    [ cases.empty_classroom, cases.student_without_activity, cases.full_classroom ].each { assert_includes classroom_keys, it }
  end

  test "accounts exist for every role, with a teacher in two schools and a head per school" do
    accounts = @set.accounts
    assert_equal @set.classrooms.size, accounts.students.size
    assert accounts.teachers.any? { it.schools.sort == %w[college lycee] }
    assert_equal @set.schools.map(&:key), accounts.directions.map(&:school)
    assert_equal %w[admin content field], accounts.team.map(&:role)
    assert accounts.team.find { it.role == "field" }.drena
  end

  test "every contact of the set falls in the fictitious range and every name comes from the list" do
    accounts = @set.accounts
    contacts = accounts.students.each_index.map { @identity.contact(role: :student, index: it) } +
               accounts.teachers.each_index.map { @identity.contact(role: :teacher, index: it) } +
               accounts.directions.each_index.map { @identity.contact(role: :direction, index: it) } +
               accounts.team.map { @identity.contact(role: it.role.to_sym, index: 0) }
    contacts.each { assert @identity.fictitious_contact?(it), it }
    assert_equal contacts.size, contacts.uniq.size
    assert_equal "0100001499", @identity.contact(role: :student, index: 1499)
    @set.schools.each { assert_kind_of String, @identity.school_name(it.key) }
  end

  test "the names file holds only plain lists" do
    assert_operator @names.fetch("noms").size, :>=, 30
    assert_equal %w[female male], @names.fetch("prenoms").keys.sort
    assert_equal @names.fetch("noms").uniq, @names.fetch("noms")
  end
end
