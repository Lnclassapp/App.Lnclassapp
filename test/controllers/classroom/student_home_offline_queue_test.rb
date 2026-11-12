require "test_helper"

# hors-connexion, Lot C (CA-15, UDR §3.6) : l'accueil élève porte « Copies à envoyer », caché tant que la file est vide (le contrôleur
# offline-queue la lit sur l'appareil) ; tous les textes viennent des locales, posés en valeurs Stimulus.
class Classroom::StudentHomeOfflineQueueTest < ActionDispatch::IntegrationTest
  setup do
    @classroom = create_classroom(level: create_level(name: "Tle"))
    @student = create_student(classroom: @classroom)
  end

  def ot(key, **) = I18n.t("offline.queue.#{key}", **)

  test "l'accueil élève rend la file cachée, avec ses textes en valeurs et le gabarit d'une copie refusée" do
    sign_in_as @student

    get student_home_path

    assert_response :success
    assert_select "#offline_queue[data-controller='offline-queue'][hidden]" do |queue|
      data = queue.first
      assert_equal ot("pending.one"), data["data-offline-queue-pending-one-value"]
      assert_equal ot("pending.other"), data["data-offline-queue-pending-other-value"]
      assert_equal ot("sending"), data["data-offline-queue-sending-value"]
      assert_equal ot("synced", percent: "%{percent}"), data["data-offline-queue-synced-value"]
      reasons = JSON.parse(data["data-offline-queue-rejected-value"])
      assert_equal %w[expired forbidden invalid locked stale wrong_owner], reasons.keys.sort
      assert_equal ot("rejected.stale"), reasons["stale"]
      assert_equal ot("rejected.locked"), reasons["locked"]
    end
    assert_select "#offline_queue[aria-live='polite'] svg"
    assert_select "#offline_queue [data-offline-queue-target='pendingText']"
    assert_select "#offline_queue ul[data-offline-queue-target='rejected']"
    assert_select "#offline_queue template[data-offline-queue-target='rejectedRow'] li.rounded-card.bg-warning-soft.px-4.py-3.text-sm.text-warning" do
      assert_select "button.min-h-tap", text: ot("dismiss")
    end
  end

  test "un enseignant n'a pas de file de copies" do
    sign_in_as create_teacher(classrooms: [ @classroom ])

    get teacher_home_path

    assert_select "#offline_queue", 0
  end
end
