require "test_helper"

# TR-01 and TR-03: the landing offers the two role entries, and every link it carries leads somewhere real.
# UDR-0059 §2.2 : the two entries are offered once, in the hero; the join section and « Commencer » are gone.
# UDR-0063 §3.4 : the footer's second list carries the public pages that are online.
# UDR-0064 §3.5 : « Blog » leads that list, « Plus sur Lnclass », once an article is published (BL-06).
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

  test "the two entries are offered once, in the hero, without the join section nor « Commencer »" do
    get root_url

    assert_select "section#rejoindre", 0
    assert_select "a, button", text: "Commencer", count: 0
    assert_select "dialog[id^='role-modal-']", 2
    assert_select "#hero dialog#role-modal-student-hero", 1
    assert_select "#hero dialog#role-modal-teacher-hero", 1
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

  # UDR-0063 §3.4 : la seconde liste du pied de page ne montre que les pages en ligne ; absente si aucune ne l'est.
  test "the footer offers no public page while none is online" do
    online = Communication::PagesController.method(:online?)
    Communication::PagesController.define_singleton_method(:online?) { |*| false }

    get root_url

    assert_select "footer #public_pages", 0
    %w[/mission /confidentialite /conditions-utilisation /conditions-vente].each do |path|
      assert_select "a[href='#{path}']", 0
    end
  ensure
    Communication::PagesController.define_singleton_method(:online?, online)
  end

  # Lot Z, décision du porteur du 2026-10-02 : les quatre pages sont en ligne.
  test "the footer links the four public pages, in the order of PAGES" do
    get root_url

    assert_select "footer #public_pages li a", 4 do |links|
      assert_equal [ mission_path, privacy_path, terms_path, sales_terms_path ], links.map { it["href"] }
    end
  end

  test "the footer lists the online public pages, and those only, in a second list" do
    online = Communication::PagesController.method(:online?)
    Communication::PagesController.define_singleton_method(:online?) { |page| %i[mission terms].include?(page.to_sym) }

    get root_url

    assert_select "footer ul#public_pages.text-sm li a", 2
    assert_select "footer #public_pages a[href='#{mission_path}']", "Notre mission"
    assert_select "footer #public_pages a[href='#{terms_path}']", "Conditions d'utilisation"
    assert_select "a[href='#{privacy_path}'], a[href='#{sales_terms_path}']", 0
  ensure
    Communication::PagesController.define_singleton_method(:online?, online)
  end

  test "BL-06: no « Blog » link in the footer while no article is published" do
    author = create_team_member(team_role: "content", second_factor: false)
    create_article(author:, status: "draft")
    create_article(author:, status: "archived")

    get root_url

    assert_select "footer ul#public_pages[aria-label='Plus sur Lnclass'] li a", 4
    assert_select "a[href='#{blog_path}']", 0
  end

  test "BL-06: once an article is published, « Blog » leads the « Plus sur Lnclass » list" do
    create_article

    get root_url

    assert_select "footer ul#public_pages[aria-label='Plus sur Lnclass'] li a", 5 do |links|
      assert_equal [ blog_path, mission_path, privacy_path, terms_path, sales_terms_path ], links.map { it["href"] }
      assert_equal "Blog", links.first.text
    end
    assert_select "a[href='#{blog_path}']", 1
  end

  test "with no public page online, a published article alone makes the second list" do
    online = Communication::PagesController.method(:online?)
    Communication::PagesController.define_singleton_method(:online?) { |*| false }
    create_article

    get root_url

    assert_select "footer #public_pages li a", 1
    assert_select "footer #public_pages a[href='#{blog_path}']", "Blog"
  ensure
    Communication::PagesController.define_singleton_method(:online?, online)
  end

  # UDR-0062 §4 : l'enseignant n'assigne plus que des exercices ; la landing ne promet plus de cours assignés.
  test "the teacher is promised to assign exercises, not courses" do
    get root_url

    assert_match "assigne-leur des exercices", response.body
    assert_no_match(/des cours et des exercices|assigner du contenu|Assigne du contenu/, response.body)
  end

  test "the school space of the former landing is not offered (TR-03, V2)" do
    get root_url

    assert_no_match(/Espace Etabl|Inscrire mon établissement|FCFA/, response.body)
  end
end
