require "test_helper"

# ADR-0077 §4.2 (ID-17) : une direction retirée qui tente de se connecter avec son bon PIN reçoit le refus d'un mauvais
# PIN ; le compte n'est pas révélé et aucune session n'est ouverte.
class Identity::ArchivedStaffSignInTest < ActionDispatch::IntegrationTest
  test "un compte direction archivé reçoit « Code secret ou numéro incorrect. » avec son bon PIN" do
    admin = create_school_admin(pin: "1357", archived_at: 2.days.ago)

    post session_path, params: { session: { contact: admin.contact, pin: "1357" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Code secret ou numéro incorrect."
    assert_equal 0, Orm::Session.where(user: admin).count
  end
end
