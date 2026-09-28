require "test_helper"

# TR-11 (ADR-0062, UDR-0049): the team finds a student or a teacher by name or by part of the number. The directory the
# UDR-0020 postponed to V4 is bounded: team only, students and teachers only, 20 per page, the number masked.
class Queries::Identity::AccountSearchQueryTest < ActiveSupport::TestCase
  Query = Queries::Identity::AccountSearchQuery

  setup do
    school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school:, name: "Tle D 1")
    @aya = create_student(classroom: @classroom, first_name: "Aya", last_name: "Kouassi", contact: "0102030445")
    @yao = create_teacher(school:, classrooms: [ @classroom, create_classroom(school:) ], first_name: "Yao", last_name: "Kouadio")
  end

  def search(term, page: 1) = Query.new.call(term:, page:)

  test "a name, without case nor accent, finds students and teachers, sorted by name, with role, school and classroom" do
    create_student(first_name: "Éric", last_name: "Kouamé")

    result = search("KOUA")

    assert_equal [ "Yao Kouadio", "Éric Kouamé", "Aya Kouassi" ], result.rows.map(&:display_name)
    assert_equal Query::Row.new(public_id: @aya.public_id, display_name: "Aya Kouassi", role: :student,
                                school_name: "Lycée Classique d'Abidjan", classroom_name: "Tle D 1", classrooms_count: nil,
                                contact: "01 •• •• •• 45"), result.rows.last
    assert_equal [ :teacher, "Lycée Classique d'Abidjan", nil, 2 ],
                 result.rows.first.to_h.values_at(:role, :school_name, :classroom_name, :classrooms_count)
    assert_equal [ nil, nil ], result.rows.second.to_h.values_at(:school_name, :classroom_name)
    assert_equal 3, result.total_count
    assert_equal "KOUA", result.term
    assert_not result.too_short
  end

  test "the first name, the full name in both orders and an accent-insensitive term all match" do
    assert_equal [ @aya.public_id ], search("aya").rows.map(&:public_id)
    assert_equal [ @aya.public_id ], search("aya kouassi").rows.map(&:public_id)
    assert_equal [ @aya.public_id ], search("Kouassi Aya").rows.map(&:public_id)
    create_student(first_name: "Aïcha", last_name: "Traoré")
    assert_equal [ "Aïcha Traoré" ], search("aicha traore").rows.map(&:display_name)
  end

  test "four digits of the number find the account; the number stays masked" do
    rows = search("03 04").rows

    assert_equal [ @aya.public_id ], rows.map(&:public_id)
    assert_equal "01 •• •• •• 45", rows.first.contact
  end

  test "team members, school admins and anonymized accounts are never found" do
    create_team_member(first_name: "Awa", last_name: "Kouakou")
    create_user(role: "school_admin", first_name: "Koffi", last_name: "Kouakou")
    create_student(first_name: "Ange", last_name: "Kouakou", anonymized_at: Time.current)

    assert_empty search("kouakou").rows
  end

  test "under 2 characters, or 3 digits, no search is made" do
    [ "a", " a ", "", nil, "123" ].each do |term|
      result = nil
      queries = count_queries { result = search(term) }

      assert_empty result.rows, term.inspect
      assert_equal 0, queries, term.inspect
      assert_equal term.to_s.strip.present?, result.too_short, term.inspect
    end
  end

  test "the SQL wildcards are escaped, never interpreted" do
    create_student(first_name: "Moussa", last_name: "Diallo")

    assert_empty search("%%").rows
    assert_empty search("a_a").rows
  end

  test "20 per page, the page clamped, the total given" do
    25.times { |index| create_student(first_name: "Élève", last_name: format("Zadi %02d", index)) }

    first = search("zadi")
    second = search("zadi", page: "2")

    assert_equal [ 20, 25, 1, 2 ], [ first.rows.size, first.total_count, first.page, first.pages ]
    assert_equal [ 5, 2 ], [ second.rows.size, second.page ]
    assert_equal "Élève Zadi 20", second.rows.first.display_name
    assert_equal 2, search("zadi", page: "99").page
    assert_equal 1, search("zadi", page: "-1").page
    # page[]=2 or page[a]=1 in the query string hands an array or a hash: page 1, never a 500.
    assert_equal 1, search("zadi", page: [ "2" ]).page
    assert_equal 1, search("zadi", page: { "a" => "1" }).page
  end

  test "the number of queries does not depend on the number of results" do
    create_student(classroom: @classroom, first_name: "Ali", last_name: "Koné")
    few = count_queries { search("ko") }
    school = create_school
    5.times do
      classroom = create_classroom(school:)
      create_student(classroom:, last_name: "Konan")
      create_teacher(school:, classrooms: [ classroom ], last_name: "Konaté")
    end

    assert_equal few, count_queries { search("ko") }
    assert_equal 4, few
  end

  private

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end
