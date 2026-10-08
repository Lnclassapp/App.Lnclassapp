require "test_helper"

# IL-11 (ADR-0085 §4.1, UDR-0081 §3.6) : le bloc « Lien de la classe » de la page d'une classe, et « Changer le lien » :
# un nouveau jeton, le bloc remplacé par Turbo Stream avec un toast, l'ancien jeton invalide, le même lien pour tous.
# IL-12 : l'enseignant de la classe, la direction de son établissement et l'équipe ; un autre enseignant ou une autre
# direction reçoit 404, un élève 403. La page de la direction est le Lot E ; ici, son geste seul.
# UDR-0081 §3.7 : l'équipe copie le lien depuis la fiche de l'établissement.
class Classroom::ClassroomLinksControllerTest < ActionDispatch::IntegrationTest
  SCOPE = "classroom.classrooms.link".freeze

  setup do
    @school = create_school(name: "Lycée Classique d'Abidjan")
    @classroom = create_classroom(school: @school, level: create_level(name: "3ème"), name: "3e 2")
    @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
    @old_token = @classroom.reload.link_token
  end

  def token = @classroom.reload.link_token
  def link_url(value = token) = join_classroom_url(value)
  def change_link(**options) = patch(classroom_link_path(@classroom.public_id), as: :turbo_stream, **options)

  def assert_link_block(url, scope: "")
    assert_select "#{scope} #classroom_link" do
      assert_select "p#classroom_link_label", text: I18n.t("#{SCOPE}.label")
      assert_select "[data-clipboard-text-value='#{url}'] button[aria-label='#{I18n.t("#{SCOPE}.copy_label")}']",
                    text: I18n.t("#{SCOPE}.copy")
      message = I18n.t("#{SCOPE}.whatsapp_message", classroom: "3e 2", url:)
      assert_select "a[href='https://wa.me/?text=#{ERB::Util.url_encode(message)}'][target=_blank][rel=noopener]",
                    text: I18n.t("#{SCOPE}.whatsapp")
      assert_select "p", text: I18n.t("#{SCOPE}.hint")
    end
  end

  def assert_link_unchanged = assert_equal(@old_token, token)

  test "IL-11 : la page de la classe montre le bloc du lien à l'enseignant, sans code ni adresse en clair" do
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_link_block link_url, scope: "#classroom_header"
    assert_select "#classroom_header [id*=join_code]", 0
    assert_select "#classroom_link button[aria-label='#{I18n.t("#{SCOPE}.more_label")}']"
    assert_select "#classroom_link [role=menuitem][aria-controls='change-classroom-link']", text: I18n.t("#{SCOPE}.change")
    assert_select "dialog#change-classroom-link" do
      assert_select "h2", text: I18n.t("#{SCOPE}.change_title")
      assert_select "form#change-classroom-link-form[action='#{classroom_link_path(@classroom.public_id)}']" \
                    " input[name=_method][value=patch]"
      assert_select "p", text: I18n.t("#{SCOPE}.change_warning")
      assert_select "button[type=submit][form=change-classroom-link-form]", text: I18n.t("#{SCOPE}.change")
    end
    assert_no_match link_url, css_select("#classroom_link").map(&:text).join
  end

  test "IL-12 : l'équipe voit le bloc du lien sur la page de la classe" do
    sign_in_as create_team_member

    get classroom_path(@classroom.public_id)

    assert_link_block link_url, scope: "#classroom_header"
  end

  test "UDR-0081 §3.6 : une classe archivée n'a pas de bloc du lien" do
    @classroom.update!(status: "archived", archived_at: Time.current)
    sign_in_as @teacher

    get classroom_path(@classroom.public_id)

    assert_response :success
    assert_select "#classroom_link", 0
  end

  test "IL-11 : « Changer le lien » remplace le bloc par le nouveau lien et pose le toast ; l'ancien jeton n'ouvre plus la classe" do
    sign_in_as @teacher

    change_link

    assert_response :success
    assert_not_equal @old_token, token
    assert_match(/\A\h{12}\z/, token)
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(I18n.t("#{SCOPE}.changed"))}/
    assert_select "turbo-stream[action=replace][target=classroom_link] template" do
      assert_link_block link_url
    end
    assert_no_match @old_token, response.body
    assert_nil Orm::Classroom.find_by(link_token: @old_token)
  end

  test "IL-11 : un second enseignant de la classe voit le même nouveau lien" do
    second = create_teacher(school: @school, classrooms: [ @classroom ])
    sign_in_as @teacher
    change_link
    sign_out

    sign_in_as second
    get classroom_path(@classroom.public_id)

    assert_not_equal @old_token, token
    assert_link_block link_url, scope: "#classroom_header"
  end

  test "IL-12 : l'équipe change le lien" do
    sign_in_as create_team_member

    change_link

    assert_response :success
    assert_not_equal @old_token, token
  end

  test "IL-12 : la direction de l'établissement de la classe change le lien" do
    sign_in_as create_school_admin(school: @school)

    change_link

    assert_response :success
    assert_not_equal @old_token, token
    assert_select "turbo-stream[action=replace][target=classroom_link]"
  end

  test "IL-12 : un enseignant qui n'enseigne pas dans la classe reçoit 404 et le lien ne change pas" do
    sign_in_as create_teacher(school: @school)

    change_link

    assert_response :not_found
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(I18n.t("errors.codes.not_found"))}/
    assert_select "turbo-stream[target=classroom_link]", 0
    assert_link_unchanged
  end

  test "IL-12 : la direction d'un autre établissement reçoit 404 et le lien ne change pas" do
    sign_in_as create_school_admin(school: create_school)

    change_link

    assert_response :not_found
    assert_link_unchanged
  end

  test "IL-12 : un élève reçoit 403 et le lien ne change pas" do
    sign_in_as create_student(classroom: @classroom)

    change_link

    assert_response :forbidden
    assert_link_unchanged
  end

  test "sans session, le changement renvoie vers la connexion" do
    change_link

    assert_redirected_to new_session_path
    assert_link_unchanged
  end

  test "une classe inconnue : 404" do
    sign_in_as create_team_member

    patch classroom_link_path("inconnue"), as: :turbo_stream

    assert_response :not_found
  end

  test "une classe archivée garde son lien : 403 et toast d'erreur, le bloc ne change pas" do
    @classroom.update!(status: "archived", archived_at: Time.current)
    sign_in_as @teacher

    change_link

    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{Regexp.escape(I18n.t("errors.codes.forbidden"))}/
    assert_select "turbo-stream[target=classroom_link]", 0
    assert_link_unchanged
  end

  test "sans JavaScript, le changement revient à la page d'où il part avec l'avis" do
    sign_in_as @teacher

    patch classroom_link_path(@classroom.public_id), headers: { "HTTP_REFERER" => classroom_url(@classroom.public_id) }

    assert_redirected_to classroom_url(@classroom.public_id)
    assert_equal I18n.t("#{SCOPE}.changed"), flash[:notice]
    assert_not_equal @old_token, token
  end

  test "sans JavaScript ni page d'origine, le changement revient à la page de la classe" do
    sign_in_as @teacher

    patch classroom_link_path(@classroom.public_id)

    assert_redirected_to classroom_path(@classroom.public_id)
  end

  test "UDR-0081 §3.7 : l'équipe copie le lien de chaque classe depuis la fiche de l'établissement, nommée dans son libellé" do
    sign_in_as create_team_member

    get school_path(@school.public_id)

    assert_response :success
    assert_select "li#classroom_#{@classroom.public_id}" do
      assert_select "[data-clipboard-text-value='#{link_url}'] button[aria-label=?]",
                    I18n.t("teams.schools.classroom_group.copy_link_label", name: "3e 2"), text: I18n.t("#{SCOPE}.copy")
      assert_select "dt", text: /code/i, count: 0
    end
    assert_no_match link_url, css_select("li#classroom_#{@classroom.public_id}").map(&:text).join
  end
end
