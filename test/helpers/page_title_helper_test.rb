require "test_helper"

# UDR-0054 §3.1 — « Page · Espace · Lnclass », composé par un seul helper.
class PageTitleHelperTest < ActionView::TestCase
  attr_accessor :current_actor

  def actor(role) = Entities::Identity::Actor.new(user_id: 1, role:)

  test "page_title returns the whole title and hands the page to the layout" do
    self.current_actor = actor(:team)

    assert_equal "Accueil · Équipe · Lnclass", page_title("Accueil")
    assert_equal "Accueil · Équipe · Lnclass", document_title
  end

  test "the space is the one of the signed-in role" do
    { student: "Élève", teacher: "Enseignant", team: "Équipe", school_admin: "Direction" }.each do |role, space|
      self.current_actor = actor(role)

      assert_equal "Cours · #{space} · Lnclass", page_title("Cours")
    end
  end

  test "a public page, or a second factor in progress, has no space" do
    assert_equal "Connexion · Lnclass", page_title("Connexion")
    assert_equal "Connexion · Lnclass", document_title
  end

  test "without a page title, the document is named after the space and the product" do
    assert_equal "Lnclass", document_title

    self.current_actor = actor(:teacher)

    assert_equal "Enseignant · Lnclass", document_title
  end

  test "an empty page title is refused" do
    [ nil, "", "   " ].each do |page|
      error = assert_raises(ArgumentError) { page_title(page) }

      assert_equal "page_title : titre vide", error.message
    end
  end

  # A modal rendered in its page composes its own title without taking the page's.
  test "the first page_title of a render names the page, the next ones only compose" do
    self.current_actor = actor(:team)

    page_title("Niveaux")

    assert_equal "Nouveau niveau · Équipe · Lnclass", page_title("Nouveau niveau")
    assert_equal "Niveaux · Équipe · Lnclass", document_title
  end

  test "the title is escaped once, never twice" do
    title = page_title("Lycée A & B")

    assert_predicate title, :html_safe?
    assert_equal "Lycée A &amp; B · Lnclass", title
    assert_equal "Lycée A &amp; B · Lnclass", document_title
  end
end
