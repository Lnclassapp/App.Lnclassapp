require "test_helper"

# UDR-0071 §3.7 « Mes annonces » and §3.8 « Formulaire », ADR-0078 §4.2 and §4.6: the team, a direction and a teacher
# write, schedule and modify their announcements from « Mes annonces »; every attempt outside their right is refused
# (403 for a student, 403 for a forged target, 404 for the announcement of someone else) and writes nothing.
class Communication::AuthoredMessagesControllerTest < ActionDispatch::IntegrationTest
  NOW = Time.zone.local(2026, 10, 4, 12)
  MP3 = ("ID3".b + ("\x00".b * 64)).freeze

  setup do
    travel_to NOW
    @lauriers = create_school(name: "Collège Les Lauriers")
    @bouake = create_school(name: "Lycée de Bouaké")
    @b3 = create_classroom(school: @lauriers, name: "3ème B")
    @c3 = create_classroom(school: @lauriers, name: "3ème C")
    @a3 = create_classroom(school: @lauriers, name: "3ème A")
    @kouassi = create_teacher(school: @lauriers, classrooms: [ @b3, @c3 ], last_name: "Kouassi", gender: "male")
    @kamate = create_school_admin(school: @lauriers, last_name: "Kamaté")
    @diallo = create_school_admin(school: @lauriers, last_name: "Diallo", gender: "male")
    @fatou = create_team_member(first_name: "Fatou")
    @awa = create_student(classroom: @b3, first_name: "Awa")
  end

  def upload(bytes, name, type) = Rack::Test::UploadedFile.new(StringIO.new(bytes), type, true, original_filename: name)

  def publish(commit: "publish", **announcement)
    post announcements_path, params: { announcement: { title: "Devoirs communs", body: "Ils commencent lundi.", illustration: "info",
                                                       visible_until: "2026-11-02", **announcement }, commit: }
  end

  def created = Orm::Message.order(:id).last
  def field_error(field) = css_select("#announcement_#{field}_error").first&.text.to_s.strip

  test "a visitor is sent to sign in, and nothing is written" do
    get my_announcements_path
    assert_redirected_to new_session_path
    get new_announcement_path
    assert_redirected_to new_session_path
    publish(audience: "students")

    assert_redirected_to new_session_path
    assert_equal 0, Orm::Message.count
  end

  test "AN-06 — a student asking for « Mes annonces », the form or the sending of an announcement receives 403" do
    sign_in_as @awa

    get my_announcements_path
    assert_response :forbidden
    get new_announcement_path
    assert_response :forbidden
    publish(audience: "students")

    assert_response :forbidden
    assert_equal 0, Orm::Message.count
  end

  test "« Mes annonces » of a teacher: title, tabs, the button « Nouvelle annonce » and the empty state" do
    sign_in_as @kouassi

    get my_announcements_path

    assert_response :success
    assert_select "title", "Mes annonces · Annonces · Enseignant · Lnclass"
    assert_select "h1", "Annonces"
    assert_select "a[href='#{new_announcement_path}']", text: "Nouvelle annonce", count: 2
    assert_select "nav#announcement-tabs a", count: 2
    assert_select "nav#announcement-tabs a[aria-current=page][href='#{my_announcements_path}']", "Mes annonces"
    assert_select "#my_announcements", 0
    assert_select "p", text: "Vous n'avez encore publié aucune annonce."
  end

  test "the tabs of the direction and of the team" do
    sign_in_as @kamate
    get my_announcements_path
    assert_select "nav#announcement-tabs a", count: 3
    assert_select "nav#announcement-tabs a[href='#{moderated_announcements_path}']", "Enseignants"
    sign_out

    sign_in_as @fatou
    get my_announcements_path
    assert_select "nav#announcement-tabs a", count: 2
    assert_select "nav#announcement-tabs a[href='#{moderated_announcements_path}']", "Toutes"
  end

  test "AN-08 — each row: its thumbnail, title, recipients and dates, its status; « Terminée » deduced from the end" do
    scheduled = create_message(author: @kamate, title: "Conseil de classe", status: "scheduled", audience: "teachers", school: @lauriers,
                               published_at: Time.zone.local(2026, 10, 5, 10))
    live = create_message(author: @kamate, title: "Devoirs communs", audience: "students", school: @lauriers,
                          published_at: Time.zone.local(2026, 10, 3, 8), ends_at: Time.zone.local(2026, 11, 2), illustration: "exam")
    ended = create_message(author: @kamate, title: "Rentrée", audience: "school_admins", school: @lauriers,
                           published_at: Time.zone.local(2026, 9, 2, 8), ends_at: Time.zone.local(2026, 10, 2))
    draft = create_message(author: @kamate, title: "Fête", status: "draft", published_at: nil, audience: "students", school: @lauriers)
    archived = create_message(author: @kamate, title: "Sortie", status: "archived", school: @lauriers, updated_at: Time.zone.local(2026, 10, 4, 9))
    withdrawn = create_message(author: @kamate, title: "Erreur", status: "withdrawn", school: @lauriers, withdrawn_at: Time.zone.local(2026, 10, 1, 9))
    Repositories::Communication::AttachmentStore.new.attach(message_id: draft.id, kind: :image, content_type: "image/png",
                                                           io: StringIO.new(file_fixture("photos/photo.png").binread), filename: "image.png")
    sign_in_as @kamate

    get my_announcements_path

    assert_select "#my_announcements ul li", count: 6
    {
      scheduled => [ "Collège Les Lauriers · Enseignants · Programmée le 5 oct. à 10:00", "Programmée" ],
      live => [ "Collège Les Lauriers · Élèves · Publiée le 3 oct. · jusqu'au 1ᵉʳ nov.", "Publiée" ],
      ended => [ "Collège Les Lauriers · Directions · Terminée le 2 oct.", "Terminée" ],
      draft => [ "Collège Les Lauriers · Élèves · Brouillon", "Brouillon" ],
      archived => [ "Collège Les Lauriers · Élèves · Archivée le 4 oct.", "Archivée" ],
      withdrawn => [ "Collège Les Lauriers · Élèves · Retirée le 1ᵉʳ oct.", "Retirée" ]
    }.each do |message, (line, status)|
      assert_select "li#my_announcement_#{message.public_id}" do
        assert_select "p.font-medium", message.title
        assert_select "p.text-mute", line
        assert_select "span.rounded-full", text: status
      end
    end
    assert_select "#my_announcement_#{draft.public_id} img[src='#{announcement_file_path(draft.public_id, kind: 'image')}'][alt='']"
    assert_select "#my_announcement_#{live.public_id} svg.size-7"
  end

  test "the menu of a row: modify, and archive behind a confirmation; none once ended, archived or withdrawn" do
    live = create_message(author: @kamate, title: "Devoirs communs", school: @lauriers)
    ended = create_message(author: @kamate, published_at: 40.days.ago, ends_at: 1.day.ago, school: @lauriers)
    archived = create_message(author: @kamate, status: "archived", school: @lauriers)
    sign_in_as @kamate

    get my_announcements_path

    assert_select "#my_announcement_#{live.public_id}" do
      assert_select "button[aria-label='Actions pour « Devoirs communs »']"
      assert_select "a[role=menuitem][href='#{edit_announcement_path(live.public_id)}']", "Modifier"
      assert_select "button[role=menuitem][aria-controls='archive-#{live.public_id}']", "Archiver"
      assert_select "dialog#archive-#{live.public_id}" do
        assert_select "h2", "Archiver cette annonce ?"
        assert_select "p", "Elle disparaîtra pour tous ses destinataires et ne pourra plus être publiée."
        assert_select "button[data-action='modal#close']", "Annuler"
        assert_select "form[action='#{announcement_archive_path(live.public_id)}'][method=post] button[type=submit]", "Archiver"
      end
    end
    [ ended, archived ].each { assert_select "#my_announcement_#{it.public_id} [role=menu]", 0 }
  end

  test "20 rows a page, the most recent first" do
    21.times { create_message(author: @fatou, audience: "all", title: "Annonce #{it}", created_at: it.minutes.ago) }
    sign_in_as @fatou

    get my_announcements_path
    assert_select "#my_announcements li", count: 20
    assert_select "#my_announcements li:first-child p.font-medium", "Annonce 0"

    get my_announcements_path(page: 2)
    assert_select "#my_announcements li p.font-medium", "Annonce 20"
  end

  test "the form of a teacher: his active classrooms, the library of illustrations, files and dates" do
    sign_in_as @kouassi

    get new_announcement_path

    assert_response :success
    assert_select "title", "Nouvelle annonce · Annonces · Enseignant · Lnclass"
    assert_select "h1", "Nouvelle annonce"
    assert_select "a[href='#{my_announcements_path}']", text: /Mes annonces/
    assert_select "form#announcement-form[action='#{announcements_path}'][method=post][enctype='multipart/form-data']" do
      assert_select "input#announcement_title[maxlength='60'][required]"
      assert_select "#announcement_title_hint", "60 caractères au plus."
      assert_select "textarea#announcement_body[maxlength='140'][rows='3'][required]"
      assert_select "#announcement_body_hint", "140 caractères au plus. Les détails peuvent aller dans l'audio."
      assert_select "fieldset legend", text: /Classes/
      assert_select "input[type=checkbox][name='announcement[classroom_public_ids][]']", count: 2
      assert_select "label", text: "3ème B"
      assert_select "label", text: "3ème C"
      assert_select "label", text: "3ème A", count: 0
      assert_select "#announcement_classroom_public_ids_hint", "Les élèves de ces classes la verront."
      assert_select "input[type=radio][name='announcement[illustration]']", count: 8
      assert_select "input[type=radio][name='announcement[illustration]'][value=info][checked]"
      assert_select "label", text: "Félicitations"
      assert_select "input[type=file][name='announcement[image]'][accept='image/png,image/jpeg,image/webp']"
      assert_select "#announcement_image_hint", "PNG, JPEG ou WebP, 2 Mo au plus. Elle remplace l'illustration."
      assert_select "input[type=file][name='announcement[audio]'][accept='audio/mpeg,audio/mp4,.mp3,.m4a']"
      assert_select "input[type=datetime-local][name='announcement[published_at]']"
      assert_select "#announcement_published_at_hint", "Laissez vide pour publier dès l'envoi."
      assert_select "input[type=date][name='announcement[visible_until]'][value='2026-11-02'][required]"
      assert_select "#announcement_visible_until_hint", "30 jours par défaut, 90 au plus."
      assert_select "a[href='#{my_announcements_path}']", "Annuler"
      assert_select "button[type=submit][name=commit][value=draft]", "Enregistrer le brouillon"
      assert_select "button[type=submit][name=commit][value=publish]", "Publier"
      assert_select "input[name='announcement[audience]']", 0
    end
  end

  test "the form of the direction: its school, three audiences without « Tous »" do
    sign_in_as @kamate

    get new_announcement_path

    assert_select "p", "Pour Collège Les Lauriers"
    assert_select "input[type=radio][name='announcement[audience]']", count: 3
    assert_select "input[type=radio][name='announcement[audience]'][value=all]", 0
    assert_select "input[name='announcement[classroom_public_ids][]']", 0
  end

  test "the form of the team: national unless it comes from the page of a school" do
    sign_in_as @fatou

    get new_announcement_path
    assert_select "input[type=hidden][name='announcement[scope]'][value=national]"
    assert_select "p", "Pour un seul établissement, partez de sa fiche."
    assert_select "input[type=radio][name='announcement[audience]']", count: 4

    get new_announcement_path(school: @lauriers.public_id)
    assert_select "input[type=hidden][name='announcement[school_public_id]'][value='#{@lauriers.public_id}']"
    assert_select "input[type=radio][name='announcement[scope]'][value=national]"
    assert_select "input[type=radio][name='announcement[scope]'][value=school][checked]"
    assert_select "label", text: "Collège Les Lauriers"
    assert_select "label", text: "Tout le pays"
  end

  test "the entry « Publier une annonce » of the page of an active school, for the team" do
    inactive = create_school(name: "Lycée fermé", status: "inactive")
    sign_in_as @fatou

    get school_path(@lauriers.public_id)
    assert_select "#school-header-actions a[role=menuitem][href=?]", new_announcement_path(school: @lauriers.public_id),
                  text: "Publier une annonce"

    get school_path(inactive.public_id)
    assert_select "#school-header-actions a[href^='#{new_announcement_path}']", 0
  end

  test "AN-01 — the team publishes now « Rentrée numérique », national, for everyone" do
    sign_in_as @fatou

    publish(title: "Rentrée numérique", scope: "national", audience: "all")

    assert_redirected_to my_announcements_path
    assert_equal "Annonce publiée.", flash[:notice]
    assert_equal [ "Rentrée numérique", "published", "all", nil, @fatou.id ], created.values_at(:title, :status, :audience, :school_id, :author_id)
    assert Orm::AuditEvent.exists?(action: "message.published", actor_id: @fatou.id, subject_id: created.id)
  end

  test "AN-02 — the team publishes « Concours de maths » for the Collège Les Lauriers, to its students" do
    sign_in_as @fatou

    publish(title: "Concours de maths", scope: "school", school_public_id: @lauriers.public_id, audience: "students")

    assert_equal [ @lauriers.id, "students" ], created.values_at(:school_id, :audience)
  end

  test "AN-03, AN-23 — a direction creates « Devoirs communs » by POST /announcements, for the students of its school" do
    sign_in_as @kamate

    publish(audience: "students")

    assert_redirected_to my_announcements_path
    assert_equal [ "Devoirs communs", @lauriers.id, "students", @kamate.id ], created.values_at(:title, :school_id, :audience, :author_id)
    under_school_admin = Rails.application.routes.routes.select { it.path.spec.to_s.start_with?("/school-admin") }
    assert_not_empty under_school_admin
    assert_empty under_school_admin.select { it.defaults[:controller].to_s.start_with?("communication/") || it.path.spec.to_s.include?("announcement") },
                 "aucune route d'annonce sous /school-admin"
    assert_equal "/announcements", announcements_path
  end

  test "AN-04 — the direction sending for the Lycée de Bouaké, nationally or for « Tous » receives 403; nothing is created" do
    sign_in_as @kamate

    [ { school_public_id: @bouake.public_id, audience: "students" }, { scope: "national", audience: "students" }, { audience: "all" } ]
      .each do |forged|
      publish(**forged)
      assert_response :forbidden
    end
    assert_equal 0, Orm::Message.count
  end

  test "AN-05 — the teacher publishes « Nouvelles fiches » for the 3ème B and the 3ème C" do
    sign_in_as @kouassi

    publish(title: "Nouvelles fiches", classroom_public_ids: [ "", @b3.public_id, @c3.public_id ])

    assert_redirected_to my_announcements_path
    assert_equal [ "classrooms", @lauriers.id ], created.values_at(:audience, :school_id)
    assert_equal [ @b3.id, @c3.id ].sort, created.message_classrooms.pluck(:classroom_id).sort
  end

  test "AN-06 — the teacher targeting the 3ème A receives 403; with no classroom, the form says so in 422" do
    sign_in_as @kouassi

    publish(classroom_public_ids: [ @a3.public_id ])
    assert_response :forbidden

    publish(classroom_public_ids: [ "" ])
    assert_response :unprocessable_entity
    assert_equal "Choisis au moins une de tes classes.", field_error(:classroom_public_ids)
    assert_select "input[type=checkbox][name='announcement[classroom_public_ids][]']", count: 2
    assert_equal 0, Orm::Message.count
  end

  test "AN-18 — a PDF renamed « affiche.png », an image of 3 MB, a WAV or an audio of 12 MB: 422, the error under the file" do
    sign_in_as @kamate
    pdf = upload(file_fixture("photos/document.pdf").binread, "affiche.png", "image/png")
    heavy = upload("\x89PNG\r\n\x1A\n".b + ("\x00".b * (3 * 1024 * 1024)), "photo.png", "image/png")
    wav = upload("RIFF\x24\x08\x00\x00WAVEfmt ".b, "message.wav", "audio/wav")
    long = upload(MP3 + ("\x00".b * (12 * 1024 * 1024)), "message.mp3", "audio/mpeg")

    { { image: pdf } => [ :image, "Ce fichier n'est pas accepté." ], { image: heavy } => [ :image, "Ce fichier est trop lourd (2 Mo au plus)." ],
      { audio: wav } => [ :audio, "Ce fichier n'est pas accepté." ], { audio: long } => [ :audio, "Ce fichier est trop lourd (10 Mo au plus)." ] }
      .each do |file, (field, message)|
      publish(audience: "students", **file)

      assert_response :unprocessable_entity
      assert_equal message, field_error(field)
      assert_select "#announcement_#{field}_hint", /choisissez de nouveau vos fichiers/
    end
    assert_equal [ 0, 0 ], [ Orm::Message.count, ActiveStorage::Attachment.count ]
  end

  test "AN-18 — a PNG of 500 KB and an MP3 are stored with the announcement" do
    sign_in_as @kamate

    publish(audience: "students", image: upload(file_fixture("photos/photo.png").binread, "affiche.png", "image/png"),
            audio: upload(MP3, "message.mp3", "audio/mpeg"))

    assert_redirected_to my_announcements_path
    assert_equal [ "image/png", "audio/mpeg" ], [ created.image.content_type, created.audio.content_type ]
  end

  test "an invalid form is shown again in 422, each error under its field, the values kept" do
    sign_in_as @kamate

    publish(audience: "teachers", title: "a" * 61, body: "", published_at: "2026-10-03T08:00", visible_until: "2026-12-31")

    assert_response :unprocessable_entity
    assert_equal [ "Le titre compte 60 caractères au plus.", "Saisissez le texte de l'annonce.",
                   "Choisissez une date à venir, ou laissez vide pour publier dès l'envoi." ],
                 [ field_error(:title), field_error(:body), field_error(:published_at) ]
    assert_select "input[type=radio][name='announcement[audience]'][value=teachers][checked]"
    assert_select "input#announcement_title[value='#{'a' * 61}']"
    assert_equal 0, Orm::Message.count
  end

  test "a future date schedules the announcement; a draft is saved" do
    sign_in_as @kamate

    publish(audience: "teachers", published_at: "2026-10-05T10:00")
    assert_equal "Annonce programmée pour le 5 oct. à 10:00.", flash[:notice]
    assert_equal "scheduled", created.status

    publish(audience: "teachers", commit: "draft")
    assert_equal "Brouillon enregistré.", flash[:notice]
    assert_equal "draft", created.status
  end

  test "the form of a published announcement: a warning, no date of publication, no draft; its files" do
    message = create_message(author: @kouassi, title: "Nouvelles fiches", audience: "classrooms", classrooms: [ @b3 ], illustration: "sheets")
    store = Repositories::Communication::AttachmentStore.new
    store.attach(message_id: message.id, kind: :image, content_type: "image/png", filename: "image.png",
                 io: StringIO.new(file_fixture("photos/photo.png").binread))
    store.attach(message_id: message.id, kind: :audio, content_type: "audio/mpeg", filename: "audio.mp3", io: StringIO.new(MP3))
    sign_in_as @kouassi

    get edit_announcement_path(message.public_id)

    assert_response :success
    assert_select "title", "Modifier l'annonce · Annonces · Enseignant · Lnclass"
    assert_select "h1", "Modifier l'annonce"
    assert_select "form#announcement-form[action='#{announcement_path(message.public_id)}']" do
      assert_select "input[name=_method][value=patch]"
      assert_select "div.bg-info-soft", "Cette annonce est publiée : la modifier la fera réapparaître chez les élèves qui l'avaient masquée."
      assert_select "input#announcement_title[value='Nouvelles fiches']"
      assert_select "input[type=checkbox][value='#{@b3.public_id}'][checked]"
      assert_select "input[type=checkbox][value='#{@c3.public_id}']:not([checked])"
      assert_select "input[type=radio][name='announcement[illustration]'][value=sheets][checked]"
      assert_select "img[src='#{announcement_file_path(message.public_id, kind: 'image')}'].size-16"
      assert_select "input[type=checkbox][name='announcement[remove_image]']"
      assert_select "label", text: "Retirer l'image"
      assert_select "audio[controls][preload=none][src='#{announcement_file_path(message.public_id, kind: 'audio')}']"
      assert_select "label", text: "Retirer l'audio"
      assert_select "input[name='announcement[published_at]']", 0
      assert_select "input[name='announcement[visible_until]'][value='#{(message.ends_at - 1).to_date.iso8601}']"
      assert_select "button[value=draft]", 0
      assert_select "button[value=publish]", "Publier"
    end
  end

  test "the form of a scheduled announcement of the team for a school: its date, its scope" do
    message = create_message(author: @fatou, status: "scheduled", school: @lauriers, audience: "teachers",
                             published_at: Time.zone.local(2026, 10, 10, 7, 30))
    sign_in_as @fatou

    get edit_announcement_path(message.public_id)

    assert_select "div.bg-info-soft", 0
    assert_select "input[type=datetime-local][value='2026-10-10T07:30']"
    assert_select "input[type=radio][name='announcement[scope]'][value=school][checked]"
    assert_select "input[type=radio][name='announcement[audience]'][value=teachers][checked]"
    assert_select "button[value=draft]", "Enregistrer le brouillon"
    assert_select "img.size-16", 0
    assert_select "audio", 0
  end

  test "AN-15 — another direction, the team and a teacher asking to modify « Devoirs communs » receive 404; it is unchanged" do
    message = create_message(author: @kamate, title: "Devoirs communs", school: @lauriers)

    [ @diallo, @fatou, @kouassi ].each do |other|
      sign_in_as other
      get edit_announcement_path(message.public_id)
      assert_response :not_found
      patch announcement_path(message.public_id), params: { announcement: { title: "Piraté", body: "Piraté", illustration: "info",
                                                                            audience: "students" }, commit: "publish" }
      assert_response :not_found
      sign_out
    end
    assert_equal [ "Devoirs communs", nil ], message.reload.values_at(:title, :edited_at)
  end

  test "an unknown announcement is 404" do
    sign_in_as @kamate

    get edit_announcement_path("inconnue")
    assert_response :not_found
  end

  test "AN-14 — the teacher modifies « Nouvelles fiches »: it comes back to Awa, who had dismissed it, marked edited" do
    message = create_message(author: @kouassi, title: "Nouvelles fiches", audience: "classrooms", classrooms: [ @b3 ])
    dismiss_message(message:, user: @awa)
    sign_in_as @kouassi

    patch announcement_path(message.public_id), params: { announcement: { title: "Nouvelles fiches", body: "Chapitre 4 en ligne.",
                                                                          illustration: "sheets", visible_until: "2026-10-30",
                                                                          classroom_public_ids: [ "", @b3.public_id ] }, commit: "publish" }

    assert_redirected_to my_announcements_path
    assert_equal "Annonce modifiée.", flash[:notice]
    assert_equal [ "Chapitre 4 en ligne.", NOW, Time.zone.local(2026, 10, 31) ], message.reload.values_at(:body, :edited_at, :ends_at)
    assert_not Orm::MessageDismissal.exists?(message_id: message.id)
  end

  test "a draft modified and published is published now" do
    draft = create_message(author: @kamate, status: "draft", published_at: nil, school: @lauriers)
    sign_in_as @kamate

    patch announcement_path(draft.public_id), params: { announcement: { title: "Fête", body: "Samedi.", illustration: "celebration",
                                                                        audience: "students" }, commit: "publish" }

    assert_equal "Annonce publiée.", flash[:notice]
    assert_equal [ "published", NOW ], draft.reload.values_at(:status, :published_at)
  end

  test "an invalid modification is shown again in 422, on the form of the announcement" do
    message = create_message(author: @kamate, school: @lauriers)
    sign_in_as @kamate

    patch announcement_path(message.public_id), params: { announcement: { title: "", body: "Lundi.", illustration: "info",
                                                                          audience: "students" }, commit: "publish" }

    assert_response :unprocessable_entity
    assert_equal "Saisissez un titre.", field_error(:title)
    assert_select "form#announcement-form[action='#{announcement_path(message.public_id)}']"
    assert_select "div.bg-info-soft"
  end

  test "AN-19 — an archived or withdrawn announcement is frozen: its form is refused, so is its modification" do
    archived = create_message(author: @kamate, status: "archived", school: @lauriers)
    sign_in_as @kamate

    get edit_announcement_path(archived.public_id)
    assert_redirected_to my_announcements_path
    assert_equal "Cette annonce est archivée ou retirée : elle ne peut plus être modifiée.", flash[:alert]

    patch announcement_path(archived.public_id), params: { announcement: { title: "Republiée", body: "Lundi.", illustration: "info",
                                                                           audience: "students" }, commit: "publish" }
    assert_redirected_to my_announcements_path
    assert_equal [ "archived", "Devoirs communs" ], archived.reload.values_at(:status, :title)
  end
end
