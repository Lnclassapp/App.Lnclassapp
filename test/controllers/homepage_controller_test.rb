require "test_helper"

# TR-01 and TR-03: the landing offers the two role entries, and every link it carries leads somewhere real.
class HomepageControllerTest < ActionDispatch::IntegrationTest
  test "the homepage is served at the root" do
    get root_url

    assert_response :success
  end

  test "the visitor sees the student and teacher entries" do
    get root_url

    assert_select "button[aria-haspopup='dialog']", text: "Je suis élève"
    assert_select "button[aria-haspopup='dialog']", text: "Je suis enseignant"
  end

  test "the student modal offers to sign in or to join a class" do
    get root_url

    assert_select "dialog#role-modal-student-hero" do
      assert_select "a[href='#{new_session_path}']", text: "Se connecter"
      assert_select "a[href='#{new_join_code_path}']", text: "Rejoindre ma classe"
    end
  end

  test "the teacher modal offers to sign in or to create an account" do
    get root_url

    assert_select "dialog#role-modal-teacher-hero" do
      assert_select "a[href='#{new_session_path}']", text: "Se connecter"
      assert_select "a[href='#{new_teacher_registration_path}']", text: "Créer un compte"
    end
  end

  test "every link is recognized by the router or targets a section of the page" do
    get root_url

    links = css_select("a[href]").map { it["href"] }

    assert_not_empty links
    links.each do |href|
      if href.start_with?("#")
        assert_select "[id='#{href.delete_prefix('#')}']", 1, "l'ancre #{href} ne vise aucune section"
      else
        assert Rails.application.routes.recognize_path(href)[:controller], "#{href} n'est reconnu par aucune route"
      end
    end
  end

  test "no button is left without an action" do
    get root_url

    css_select("button").each do |button|
      assert(button["data-action"].present? || button["type"] == "submit", "bouton sans action : #{button.text.squish}")
    end
  end

  test "the school space of the former landing is not offered (TR-03, V2)" do
    get root_url

    assert_no_match(/Espace Etabl|Inscrire mon établissement|FCFA/, response.body)
  end
end
