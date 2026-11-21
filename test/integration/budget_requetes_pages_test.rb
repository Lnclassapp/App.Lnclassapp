require "test_helper"

# Garde de régression (chantier pages-sous-600ms, lot B) : chaque page principale de l'élève, de l'enseignant et de la direction a un budget de requêtes SQL.
# Un budget = compte mesuré sur ces données + 25 %, arrondi au supérieur ; on le monte seulement après avoir mesuré (script/mesure/pages) et expliqué la hausse.
# Un échec veut dire qu'une page a gagné des requêtes (souvent une par devoir ou par notion) : la corriger avant de toucher au budget.
class BudgetRequetesPagesTest < ActionDispatch::IntegrationTest
  # page => budget ; en commentaire, le compte relevé sur le jeu standard (production locale, 2026-11-21).
  BUDGETS = {
    "élève : accueil" => 38,                         # 26
    "élève : ma classe" => 48,                       # 91
    "élève : catalogue" => 18,                       # 15
    "élève : matière" => 17,                         # 13
    "élève : leçon" => 38,                           # 42
    "élève : exercice" => 28,                        # 23
    "enseignant : accueil" => 32,                    # 30
    "enseignant : classe" => 40,                     # 30
    "enseignant : élève de la classe" => 27,         # 22
    "enseignant : leçon de la classe" => 32,         # 26
    "enseignant : suivi d'un devoir" => 28,          # 23
    "direction : classes" => 12,                     # 10
    "direction : classe" => 23,                      # 18
    "direction : niveau" => 18,                      # 14
    "direction : enseignants" => 13                  # 10
  }.freeze

  setup do
    school = create_school
    level = create_level(name: "3ème")
    @classroom = create_classroom(school:, level:)
    @student = create_student(classroom: @classroom)
    @teacher = create_teacher(school:, classrooms: [ @classroom ])
    @direction = create_school_admin(school:)
    @material = create_material(name: "SVT")
    @course = create_course(level:, material: @material, name: "Génétique")
    other = create_course(level:, material: @material, name: "Écologie")
    @exercises = [ @course, @course, other ].map { create_exercise(essential: create_essential(course: it)) }
    @assignments = @exercises.map { create_assignment(classroom: @classroom, assignable: it, by: @teacher) }
  end

  def count_queries
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  def assert_budget(page, path)
    get path
    # Le cache de requêtes du test survit d'une visite à l'autre ; en production, il repart vide à chaque requête.
    ActiveRecord::Base.connection_pool.clear_query_cache
    count = count_queries { get path }
    assert_response :success, "#{page} (#{path})"
    budget = BUDGETS.fetch(page)
    assert_operator count, :<=, budget,
                    "#{page} : #{count} requêtes SQL pour un budget de #{budget} ; mesurer avec script/mesure/pages"
  end

  test "élève : les pages principales restent dans leur budget de requêtes" do
    sign_in_as @student
    assert_budget "élève : accueil", "/students"
    assert_budget "élève : ma classe", "/students/classroom"
    assert_budget "élève : catalogue", "/courses"
    assert_budget "élève : matière", "/courses?material=#{@material.slug}"
    assert_budget "élève : leçon", "/courses/#{@course.slug}"
    assert_budget "élève : exercice", "/exercises/#{@exercises.first.public_id}"
  end

  test "enseignant : les pages principales restent dans leur budget de requêtes" do
    sign_in_as @teacher
    base = "/classrooms/#{@classroom.public_id}"
    assert_budget "enseignant : accueil", "/teachers"
    assert_budget "enseignant : classe", base
    assert_budget "enseignant : élève de la classe", "#{base}/students/#{@student.public_id}"
    assert_budget "enseignant : leçon de la classe", "#{base}/courses/#{@course.slug}"
    assert_budget "enseignant : suivi d'un devoir", "#{base}/assignments/#{@assignments.last.public_id}"
  end

  test "direction : les pages principales restent dans leur budget de requêtes" do
    sign_in_as @direction
    assert_budget "direction : classes", "/school-admin/classrooms"
    assert_budget "direction : classe", "/school-admin/classrooms/#{@classroom.public_id}"
    assert_budget "direction : niveau", "/school-admin/levels/#{@classroom.level.slug}"
    assert_budget "direction : enseignants", "/school-admin/teachers"
  end
end
