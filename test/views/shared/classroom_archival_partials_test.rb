require "test_helper"

# UDR-0083 : les trois partiels partagés des lots A et B, rendus seuls.
class ClassroomArchivalPartialsTest < ActiveSupport::TestCase
  def render(partial, **locals) = Nokogiri::HTML.fragment(ApplicationController.render(partial: "shared/#{partial}", locals:))

  def classroom_menu(archived: false, students_count: 12, teachers_count: 1)
    render("classroom_archive_menu", name: "6ème 1", public_id: "abc", archived:, students_count:, teachers_count:,
                                    archive_path: "/archive", restore_path: "/restore")
  end

  test "la carte d'une classe active propose « Archiver » avec une confirmation qui chiffre l'impact" do
    html = classroom_menu

    assert_includes html.text, "Archiver la classe"
    assert_includes html.text, "12 élèves et 1 enseignant ne la verront plus"
    assert_includes html.text, "Rien n'est supprimé"
    assert_equal "/archive", html.at_css("form#archive-classroom-abc-form")["action"]
    assert_equal "patch", html.at_css("form#archive-classroom-abc-form input[name=_method]")["value"]
  end

  test "la carte d'une classe archivée propose « Restaurer » sans confirmation" do
    html = classroom_menu(archived: true)

    assert_includes html.text, "Restaurer la classe"
    assert_not_includes html.text, "Archiver la classe"
    assert_equal "/restore", html.at_css("a[href='/restore']")["href"]
    assert_nil html.at_css("form")
  end

  test "le menu d'un niveau chiffre les classes, élèves et enseignants, et envoie le slug du niveau" do
    html = render("level_archive_menu", name: "6ème", slug: "6eme", classrooms_count: 5, students_count: 142, teachers_count: 4,
                                       archive_path: "/archive-level")

    assert_includes html.text, "Archiver les 5 classes de 6ème ?"
    assert_includes html.text, "142 élèves et 4 enseignants ne les verront plus"
    assert_equal "/archive-level", html.at_css("form#archive-level-6eme-form")["action"]
    assert_equal "6eme", html.at_css("form input[name=level]")["value"]
  end

  test "le bouton des archives dit combien sont masquées, se retourne une fois affichées, et disparaît à zéro" do
    assert_includes render("archives_toggle", hidden_count: 3, shown: false, show_path: "/?archives=1", hide_path: "/").text,
                    "Afficher les archives (3)"
    shown = render("archives_toggle", hidden_count: 3, shown: true, show_path: "/?archives=1", hide_path: "/")
    assert_includes shown.text, "Masquer les archives"
    assert_equal "true", shown.at_css("a")["aria-expanded"]
    assert_predicate render("archives_toggle", hidden_count: 0, shown: false, show_path: "/?archives=1", hide_path: "/").text.strip, :empty?
  end
end
