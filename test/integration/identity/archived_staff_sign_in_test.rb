require "test_helper"

# ADR-0077 §4.2 (ID-17) : une direction retirée qui tente de se connecter avec son bon PIN reçoit le refus d'un mauvais
# PIN ; le compte n'est pas révélé et aucune session n'est ouverte.
class Identity::ArchivedStaffSignInTest < ActionDispatch::IntegrationTest
  test "un compte direction archivé reçoit « Numéro ou code secret incorrect. » avec son bon PIN" do
    admin = create_school_admin(pin: "1357", archived_at: 2.days.ago)

    post session_path, params: { session: { contact: admin.contact, pin: "1357" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "Numéro ou code secret incorrect."
    assert_equal 0, Orm::Session.where(user: admin).count
  end
end
