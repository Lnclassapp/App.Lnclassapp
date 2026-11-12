require "application_system_test_case"

# CA-7 (parcours) — hors-connexion Lot B : l'élève ouvre le sujet (le paquet est rangé sur le téléphone), fait la copie hors ligne, lit sa note
# « Provisoire » avec le corrigé ; la copie est en file dans la base locale, aucune session n'est ouverte sur le serveur.
class Assessment::OfflineCopyTest < ApplicationSystemTestCase
  setup do
    @exercise = create_exercise(title: "Méiose", questions: 2, statement: "Étudie la méiose.")
    @exercise.questions.order(:position).first.update!(explanation: "Deux divisions.")
    @student = create_student_for(@exercise.essential.course)
    sign_in_as @student
  end

  test "le paquet est rangé à l'ouverture du sujet, la copie est corrigée sur le téléphone puis mise en file" do
    with_mobile_viewport do
      visit exercise_path(@exercise.public_id)
      assert_selector "#start-exercise-form[data-controller='offline-start']"
      wait_for_local_count("packs", 1)

      visit offline_copy_exercise_path(@exercise.public_id)
      assert_selector "form#copy-form[data-controller='offline-copy']"
      assert_selector "#copy-counter", text: "0/2"
      choose "Proposition 1", match: :first
      assert_selector "#copy-counter", text: "1/2"
      click_on I18n.t("assessment.exercise_sessions.show.submit")

      assert_selector "#offline_result", text: I18n.t("offline.result.provisional")
      assert_selector "#offline_result p", text: "50 %"
      assert_selector "#offline_result li", count: 2
      assert_selector "#offline_result li", text: I18n.t("offline.result.verdict.correct")
      assert_selector "#offline_result li", text: I18n.t("offline.result.verdict.wrong")
      assert_selector "#offline_result li", text: "Deux divisions."
      assert_selector "#offline_result li", text: I18n.t("assessment.session_results.question_review.right_answer")
      assert_equal "offline_result_title", page.evaluate_script("document.activeElement.id")
      assert_no_selector "#copy-form"
      assert_link I18n.t("offline.result.back"), href: exercise_path(@exercise.public_id)
    end

    wait_for_local_count("copies", 1)
    assert_equal 0, Orm::ExerciseSession.where(student: @student).count
  end

  test "trois copies d'affilée de l'exercice en file : la page dit l'heure de reprise à la place des questions" do
    visit exercise_path(@exercise.public_id)
    wait_for_local_count("packs", 1)
    seed_copies(minutes_ago: [ 20, 10, 1 ])

    visit offline_copy_exercise_path(@exercise.public_id)

    assert_selector "#exercise_paused", text: /Tu pourras recommencer à \d{2} h \d{2}\./
    assert_no_selector "#copy-form ol"
    assert_no_button I18n.t("assessment.exercise_sessions.show.submit")
  end

  private

  def seed_copies(minutes_ago:)
    page.evaluate_async_script(<<~JS, @exercise.public_id, minutes_ago)
      const [exercise, minutes, done] = arguments
      const name = "lnclass-offline-" + document.querySelector('meta[name="lnclass-offline-key"]').content
      const request = indexedDB.open(name)
      request.onsuccess = () => {
        const db = request.result
        const tx = db.transaction("copies", "readwrite")
        minutes.forEach((ago, index) => tx.objectStore("copies").put({
          client_copy_id: "seed-" + index, exercise_public_id: exercise, pack_token: "t", status: "pending", answers: {}, provisional_percent: 0,
          started_at: new Date(Date.now() - (ago + 1) * 60000).toISOString(), submitted_at: new Date(Date.now() - ago * 60000).toISOString() }))
        tx.oncomplete = () => { db.close(); done(true) }
      }
    JS
  end

  # Le nombre de lignes d'un magasin de la base locale de la clé (attend que la base existe : l'ouvrir la créerait vide).
  def wait_for_local_count(store, expected)
    script = <<~JS
      const done = arguments[arguments.length - 1]
      const name = "lnclass-offline-" + document.querySelector('meta[name="lnclass-offline-key"]').content
      indexedDB.databases().then((all) => {
        if (!all.some((db) => db.name === name)) return done(0)
        const request = indexedDB.open(name)
        request.onsuccess = () => {
          const db = request.result
          const count = db.transaction("#{store}").objectStore("#{store}").count()
          count.onsuccess = () => { db.close(); done(count.result) }
        }
      })
    JS
    deadline = Time.current + 10
    count = 0
    while Time.current < deadline
      count = page.evaluate_async_script(script)
      break if count == expected

      sleep 0.2
    end
    assert_equal expected, count, "la base locale devait contenir #{expected} ligne(s) dans #{store}"
  end
end
