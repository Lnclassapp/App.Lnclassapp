require "application_system_test_case"

# The nominal journeys of the PRD of annonces-v2 (§3), in a real browser, end to end.
# On his phone, M. Kouassi has 3 live announcements, « Réunion parents » the oldest. He opens « Nouvelle annonce »: the
# notice names « Réunion parents »; the counter follows his typing (« 18 / 60 »); he picks the theme « Mangue », the drawing
# « Bus scolaire » of the team and a phone recording (M4A of brand 3gp4); he publishes, and the toast names the archived
# one. On hers, Awa finds the new card in her carousel, orange (theme « Mangue ») with the drawing of the team, and
# « Réunion parents » no more. Fatou goes from « Référentiel » to the tile « Illustrations d'annonce »: a trapped SVG is
# refused with its message, a drawing is added, then retired.
#
# One journey, one sign-in per actor: the chantier has 15 s of system suite (ADR-0069 §9). What another test already plays
# stays there: the thresholds of the counter and its announcement (AV-01, character_count of UDR-0067), the contrasts of
# the 10 themes (AV-07, announcement_themes_test), each trapped SVG (AV-09, drawing_reader_test and
# announcement_illustrations_controller_test), each audio variant (AV-12, audio_header_test), the 403 of AV-11, and a
# drawing kept on a live announcement once retired (AV-10, authored_messages_controller_test).
class Communication::AnnouncementsV2JourneyTest < ApplicationSystemTestCase
  RECORDING = "audio/marque-3gp4.m4a".freeze
  # A drawing of the team that no base illustration has: a disc of radius 21 (the reading of an SVG keeps its geometry).
  DISC = { "name" => "circle", "attributes" => { "cx" => "32", "cy" => "32", "r" => "21" }, "children" => [] }.freeze

  setup do
    lauriers = create_school(name: "Collège Les Lauriers")
    @troisieme_b = create_classroom(school: lauriers, name: "3ème B")
    @kouassi = create_teacher(school: lauriers, material: create_material(name: "SVT"), classrooms: [ @troisieme_b ],
                              gender: "male", last_name: "Kouassi")
    @awa = create_student(classroom: @troisieme_b, first_name: "Awa")
    @fatou = create_team_member(first_name: "Fatou")
    @bus = create_illustration(name: "Bus scolaire", created_by: @fatou, shapes: [ DISC ])
    @reunion, = { "Réunion parents" => 5, "Fiches chapitre 3" => 3, "Sortie au musée" => 1 }.map do |title, days|
      create_message(author: @kouassi, title:, audience: "classrooms", classrooms: [ @troisieme_b ], published_at: days.days.ago)
    end
  end

  def tc(key, **) = I18n.t("communication.#{key}", **)
  def ti(key, **) = I18n.t("teams.announcement_illustrations.#{key}", **)
  def field(attribute) = Dtos::Communication::MessageInput.human_attribute_name(attribute)
  def carousel_titles = all("#student_home_announcements li article h3").map(&:text)

  # On a phone, as a finger would: the element first brought into view, out of the fixed bottom bar.
  def tap(node)
    page.execute_script("arguments[0].scrollIntoView({ behavior: 'instant', block: 'center', inline: 'start' })", node)
    node.click
  end

  test "AV-01, AV-03, AV-06, AV-07, AV-08, AV-09, AV-10, AV-12 — M. Kouassi publishes a 4th announcement; Awa reads it; Fatou manages the library" do
    with_mobile_viewport do
      publish_as_kouassi
      read_as_awa
    end

    manage_the_library_as_fatou
  end

  private

  # PRD §3, steps 1 to 6: the notice, the counter, the theme, the drawing of the team, the recording, the toast.
  def publish_as_kouassi
    sign_in_as @kouassi
    visit my_announcements_path
    click_on tc("authored_messages.index.new"), match: :first

    within("#announcement-cap-notice") { assert_text tc("authored_messages.form.cap.notice", count: 3, title: "Réunion parents") }
    fill_in field(:title), with: "Réunion de rentrée"
    assert_selector "div:has(> div > #announcement_title) > [data-communication--character-count-target=count]", text: "18 / 60"
    fill_in field(:body), with: "La réunion de rentrée a lieu jeudi à 17 h. Le détail est dans l'audio."
    tap find("label", text: tc("themes.mangue"))
    assert_selector "fieldset#announcement-illustrations[data-announcement-theme=mangue]"
    tap find("fieldset#announcement-illustrations label", text: "Bus scolaire")
    tap find("label", text: "3ème B")
    attach_file field(:audio), file_fixture(RECORDING)
    tap find_button(tc("authored_messages.form.publish"))

    assert_current_path my_announcements_path
    assert_toast "#{tc('authored_messages.saved.published')} « Réunion parents » est archivée."
    within("#my_announcement_#{@reunion.public_id}") { assert_text "Archivée le" }
    sign_out
  end

  # PRD §3, step 7: the new card, in its theme, with the drawing of the team; « Réunion parents » has left.
  def read_as_awa
    rentree = Orm::Message.find_by!(title: "Réunion de rentrée")
    assert_equal [ "mangue", @bus.id, "audio/mp4" ], [ rentree.theme, rentree.illustration_id, rentree.audio.content_type ]
    sign_in_as @awa

    assert_current_path student_home_path
    within("#announcement_#{rentree.public_id}[data-announcement-theme=mangue]") do
      assert_selector "svg.fill-brand-strong circle[r='21']"
      assert_selector "audio[preload=none]", visible: :all
    end
    assert_equal [ "Réunion de rentrée", "Sortie au musée", "Fiches chapitre 3" ], carousel_titles
    sign_out
  end

  # PRD §3, the other nominal path: from « Référentiel », a trapped SVG refused, a drawing added, then retired.
  def manage_the_library_as_fatou
    sign_in_as @fatou
    within("nav#sidebar_secondary") { click_link I18n.t("shared.navigation.referential") }
    tile = find("#team_referential a[href='#{teams_announcement_illustrations_path}']")
    assert_match(/\A9\s+illustrations d'annonce/, tile.text)
    tile.click

    assert_current_path teams_announcement_illustrations_path
    add_illustration("Piège", "illustrations/script.svg")
    assert_selector "#illustration_file_error", text: "Ce dessin n'est pas accepté : il contient autre chose que des formes."
    add_illustration("Étoile", "illustrations/pictogram.svg")
    assert_toast ti("create.added")

    star = Orm::MessageIllustration.find_by!(name: "Étoile")
    click_menu_action("#illustration_#{star.public_id}", ti("illustration.retire"))
    within("dialog[open]") { click_on ti("illustration.confirm") }

    assert_toast I18n.t("teams.announcement_illustration_retirements.create.retired")
    within("#illustration_#{star.public_id}") { assert_text ti("illustration.retired") }
    assert_equal [ false, true ], [ Orm::MessageIllustration.exists?(name: "Piège"), star.reload.retired_at.present? ]
  end

  def add_illustration(name, fixture)
    fill_in Dtos::Communication::IllustrationInput.human_attribute_name(:name), with: name
    attach_file Dtos::Communication::IllustrationInput.human_attribute_name(:file), file_fixture(fixture)
    click_on ti("index.submit")
  end
end
