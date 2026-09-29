require "application_system_test_case"

# Finitions UX, Lot E (UDR-0054, amendements d'UDR-0027 et d'UDR-0050) : la classe vue par l'enseignant et par l'équipe,
# « Inviter un collègue ». FU-02 (enseignant), FU-07, FU-08, FU-10 (Inviter un collègue), FU-26 (classe), FU-28, FU-48,
# FU-53 (classe).
module Finitions; end

class Finitions::ClassroomTest < ApplicationSystemTestCase
  SCOPE = "classroom.classrooms".freeze

  setup do
    @school = create_school(name: "Lycée moderne de Cocody", school_code: "k7m4qz")
    @classroom = create_classroom(school: @school, level: create_level(name: "3e"), name: "3e A", join_code: "kfm37",
                                  max_students: 40)
    @teacher = create_teacher(school: @school, classrooms: [ @classroom ])
    @awa = create_student(classroom: @classroom, first_name: "Awa", last_name: "Bamba")
    @koffi = create_student(classroom: @classroom, first_name: "Koffi", last_name: "Yao")
    @elsewhere = create_student(classroom: create_classroom(school: @school, name: "3e B"), first_name: "Awa", last_name: "Ailleurs")
    page.driver.browser.execute_cdp("Browser.grantPermissions", permissions: %w[clipboardReadWrite clipboardSanitizedWrite])
  end

  def t(key, **) = I18n.t(key, **)
  def clipboard = page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")
  def no_horizontal_scroll? = page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
  def first_main_link = find("main#main a", match: :first)
  def shares = Orm::ReferralShare.where(user: @teacher).order(:id).pluck(:channel)

  test "FU-02, FU-08 : l'accueil de l'enseignant se distingue ; de la classe, « Accueil » y ramène" do
    sign_in_as @teacher

    visit teacher_home_path
    assert_title "Accueil · Enseignant · Lnclass"

    visit classroom_path(@classroom.public_id)
    assert_title "3e A · Enseignant · Lnclass"
    within("nav[aria-label='Retour']") { assert_link t("#{SCOPE}.header.back"), href: teacher_home_path }
    assert_equal t("#{SCOPE}.header.back"), first_main_link.text

    first_main_link.click

    assert_current_path teacher_home_path
  end

  test "FU-07 : l'équipe ouvre la classe depuis la fiche de l'établissement et y revient par son nom" do
    sign_in_as create_team_member
    visit school_path(@school.public_id)

    click_on "3e A"

    assert_current_path classroom_path(@classroom.public_id)
    assert_title "3e A · Équipe · Lnclass"
    within("nav[aria-label='Retour']") { click_on "Lycée moderne de Cocody" }
    assert_current_path school_path(@school.public_id)
  end

  test "FU-26 : l'enseignant copie le code en majuscules et le lien /c/<code> de sa classe" do
    sign_in_as @teacher
    visit classroom_path(@classroom.public_id)

    assert_no_page_reload do
      click_on t("#{SCOPE}.header.copy")
      assert_toast t("shared.clipboard.copied_code")
    end
    assert_equal "KFM37", clipboard

    click_on t("#{SCOPE}.header.copy_link")

    assert_toast t("shared.clipboard.copied_link")
    assert_equal URI.join(page.current_url, join_classroom_path("KFM37")).to_s, clipboard
    assert_selector "[data-controller~='classroom--join-code-copy']", count: 0
  end

  test "FU-48, FU-51 : « Chercher un élève » filtre la liste pendant la frappe, sans recharger la page" do
    sign_in_as @teacher
    visit classroom_path(@classroom.public_id)
    assert_selector "#classroom_roster_list li", count: 2
    assert_no_button t("#{SCOPE}.roster.search_submit")

    assert_no_page_reload do
      fill_in t("#{SCOPE}.roster.search_label"), with: "a"
      sleep 0.6
      assert_selector "#classroom_roster_list li", count: 2
      assert_no_current_path(/q=/)

      fill_in t("#{SCOPE}.roster.search_label"), with: "awa"

      assert_selector "#classroom_roster_list [aria-live=polite]", text: t("#{SCOPE}.roster.count", count: 1)
      assert_selector "#classroom_roster_list li", count: 1
      assert_selector "#student_#{@awa.public_id}", text: "Awa Bamba"
      assert_no_selector "#student_#{@koffi.public_id}"
      assert_no_selector "#student_#{@elsewhere.public_id}"
      assert_current_path classroom_path(@classroom.public_id, q: "awa")
      assert_field t("#{SCOPE}.roster.search_label"), with: "awa", focused: true

      fill_in t("#{SCOPE}.roster.search_label"), with: ""

      assert_selector "#classroom_roster_list li", count: 2
    end
  end

  test "FU-48 : une recherche sans résultat propose d'effacer la recherche ; une classe vide n'a pas de champ" do
    empty = create_classroom(school: @school, name: "3e C")
    Orm::TeacherClassroom.create!(teacher: @teacher, classroom: empty)
    sign_in_as @teacher
    visit classroom_path(@classroom.public_id)

    fill_in t("#{SCOPE}.roster.search_label"), with: "zzz"

    within("#classroom_roster_list") { click_on t("#{SCOPE}.roster.clear_search") }
    assert_selector "#classroom_roster_list li", count: 2
    assert_field t("#{SCOPE}.roster.search_label"), with: ""

    visit classroom_path(empty.public_id)
    assert_selector "#classroom_roster_empty"
    assert_no_field t("#{SCOPE}.roster.search_label")
  end

  test "FU-48 : le code de récupération se génère toujours depuis la liste filtrée" do
    sign_in_as @teacher
    visit classroom_path(@classroom.public_id, q: "awa")

    within("#student_#{@awa.public_id}") { click_on t("#{SCOPE}.roster.issue_code") }

    assert_selector "dialog[open]", text: "Awa Bamba"
    assert_no_selector "dialog[open] [data-controller=clipboard]"
  end

  test "FU-53 : à 390 px, la page de la classe ne déborde pas, aides ouvertes" do
    sign_in_as @teacher
    with_mobile_viewport do
      visit classroom_path(@classroom.public_id)

      assert no_horizontal_scroll?, "la page déborde en largeur"
      all("#classroom_header summary, #classroom_roster summary").each(&:click)

      assert_text t("#{SCOPE}.header.headcount_tip", max: 40)
      assert_text t("#{SCOPE}.roster.last_score_tip")
      assert no_horizontal_scroll?, "une aide ouverte fait déborder la page"
    end
  end

  test "FU-10 : « Inviter un collègue » revient à « Classes »" do
    sign_in_as @teacher
    visit teacher_invite_path

    assert_title "Inviter un collègue · Enseignant · Lnclass"
    assert_equal t("identity.referrals.show.back"), first_main_link.text
    first_main_link.click

    assert_current_path teacher_classrooms_path
  end

  test "FU-28 : la copie du lien de parrainage passe par clipboard et reste comptée ; une copie refusée ne l'est pas" do
    sign_in_as @teacher
    visit teacher_invite_path
    link = find("a#referral_link")[:href]

    click_on t("identity.referrals.invite.copy")

    assert_toast t("shared.clipboard.copied_link")
    assert_equal link, clipboard
    Timeout.timeout(10) { sleep 0.1 until shares == %w[copy] }

    page.execute_script("navigator.clipboard.writeText = () => Promise.reject(new Error('refusé'))")
    click_on t("identity.referrals.invite.copy")

    assert_toast t("shared.clipboard.failed")
    sleep 0.5
    assert_equal %w[copy], shares
  end
end
