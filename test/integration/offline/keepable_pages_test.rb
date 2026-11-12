require "test_helper"

# hors-connexion, Lot A, CA-1 (ADR §4.1, menace P6) : seule une liste fermée d'actions pose « Lnclass-Offline: keep ».
# Ce test liste les actions qui le posent ; il échoue si la liste change sans lui (le Lot D y ajoutera les pages d'enseignant).
class KeepablePagesTest < ActionDispatch::IntegrationTest
  KEEP = "Lnclass-Offline".freeze

  setup do
    course = create_course(name: "Génétique", level: create_level(name: "Tle"), series: create_series(name: "D"),
                           material: create_material(name: "SVT", category: "science"))
    @course = course
    @exercise = create_exercise(essential: create_essential(course:, name: "La méiose"), title: "Méiose")
    @student = create_student_for(course)
  end

  test "l'élève connecté : la leçon, le sujet d'exercice et l'accueil portent l'en-tête" do
    sign_in_as @student

    [ course_path(@course.slug), exercise_path(@exercise.public_id), student_home_path ].each do |path|
      get path

      assert_response :success, path
      assert_equal "keep", response.headers[KEEP], "#{path} devrait être gardable"
    end
  end

  test "sans connexion, aucune page ne porte l'en-tête" do
    get new_session_path
    assert_not_equal "keep", response.headers[KEEP]

    get course_path(@course.slug)
    assert_not_equal "keep", response.headers[KEEP]
  end

  test "l'équipe, le profil, la connexion et la déconnexion ne le portent jamais" do
    sign_in_as @student
    [ courses_path, profile_path, edit_profile_pin_path ].each do |path|
      get path
      assert_nil response.headers[KEEP], "#{path} ne doit pas être gardable"
    end

    get new_session_path
    assert_nil response.headers[KEEP]
  end

  test "la liste fermée : seuls ces contrôleurs déclarent keep_offline, pour show (et la copie hors ligne du Lot B pour new)" do
    declared = Rails.root.glob("app/controllers/**/*.rb").filter_map do |file|
      lines = file.read.scan(/^\s*keep_offline\b[^#\n]*/)
      [ file.relative_path_from(Rails.root).to_s, lines.map(&:strip) ] if lines.any?
    end.to_h

    assert_equal(
      { "app/controllers/assessment/exercises_controller.rb" => [ "keep_offline only: :show" ],
        "app/controllers/assessment/offline_copies_controller.rb" => [ "keep_offline only: :new" ],
        "app/controllers/catalog/courses_controller.rb" => [ "keep_offline only: :show" ],
        "app/controllers/classroom/student_homes_controller.rb" => [ "keep_offline only: :show" ] },
      declared
    )
  end
end
