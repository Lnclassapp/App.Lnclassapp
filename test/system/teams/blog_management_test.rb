require "application_system_test_case"

# UDR-0067 §3.10, ADR-0074 §7 — the team writes the blog in the browser, end to end, in one journey that signs in once
# (ADR-0069 §9, budget of the system suite). First, the course editor still refuses any image (BL-15). Nominal path A: a
# Contenu member opens « Blog » from the team home, writes a draft with a cover (taken off, then chosen again) and two
# images in its text (shrunk in the browser, sent to the team endpoint while Trix shows its progress bar), leaves one text
# alternative empty, sees the publication refused on that image (BL-13), takes an image out of the text and brings it
# back, completes it, publishes (BL-07), reads the public page with its images served by Lnclass (BL-14) and archives,
# under the strict CSP. Then, on a phone, the list and the modal never scroll sideways (C1); in that modal, a GIF, a fake
# .jpg, an image too heavy even shrunk and an image pasted from a web page are refused with their reason (BL-12), and an
# upload that never answers, fails while « Créer le brouillon » waits, or meets an expired session frees the editor and
# the cover. Last, a visitor on a phone meets « Cet article n'est plus disponible », and titles of one word wider than
# the screen wrap on the public pages (C1).
#
# Only what needs a browser is here. The rest is proven without one: what the server renders and refuses in
# test/controllers/teams/articles_controller_test.rb (the edit modal and its images, BL-13 in 422, publish, archive and
# republish morphed and audited, a save without cover deletes it), the endpoint's answers in
# test/controllers/teams/article_images_controller_test.rb (BL-12 in 422, 401 on an expired session), the public page in
# test/controllers/communication/articles_controller_test.rb (BL-14: src, alt, lazy) and
# test/integration/communication/articles_test.rb (BL-05: 410; BL-11: put back online at the same address).
class Teams::BlogManagementTest < ApplicationSystemTestCase
  # Shrinking a photo, then sending it, under a loaded full suite.
  UPLOAD_WAIT = 20
  IMAGE = Entities::Communication::ArticleImage
  # C1: titles that carry one word wider than a phone, measured at 360 and 390 px. An address pasted in a title is a single
  # « word » of 50 characters, wider than a card of 360 px.
  LONG_TITLE = "Anticonstitutionnellement : le mot le plus long du français".freeze
  URL_TITLE = "Inscriptions sur lnclass.com/eleves/inscription-rentree-2026".freeze
  PHONES = [ [ 360, 780 ], MOBILE_VIEWPORT ].freeze

  setup do
    @member = create_team_member(team_role: "content", first_name: "Awa", last_name: "Koné")
    sign_in_as @member
    assert_current_path team_home_path
    record_csp_violations
  end

  def t(key, **) = I18n.t(key, **)
  def tf(key, **) = t("teams.articles.form.#{key}", **)
  # The ceilings of the messages come from ArticleImage, as the form helper writes them (« 1 Mo », 10).
  def image_message(key, **) = tf("image_messages.#{key}", max_bytes: helpers.number_to_human_size(IMAGE::MAX_BYTES), max_count: IMAGE::MAX_PER_ARTICLE, **)
  def helpers = ApplicationController.helpers
  def refused(name, reason) = image_message("refused", name:, reason:)
  def fixture(path) = file_fixture(path).to_s
  def editor = find_rich_text_editor("trix-editor#article_body")

  test "path A: a draft with a cover and two shrunk images, refused then published, read in public, archived; every refusal; then gone" do
    # Two published articles whose titles carry one word wider than a phone (C1).
    long_article = create_article(author: @member, title: LONG_TITLE, cover: create_article_image)
    url_article = create_article(author: @member, title: URL_TITLE, published_at: 1.day.ago)
    stored = Orm::ArticleImage.count

    # 1. BL-15, from the team home, before any upload of the blog: the course editor still refuses any image, no button, a
    # dropped photo never reaches the server.
    create_course(name: "Génétique et évolution")
    open_in_modal(new_teams_course_path)
    within "turbo-frame#modal dialog[open]" do
      course_editor = find_rich_text_editor
      course_editor.click
      course_editor.send_keys("ADN")
      drop_generated_image(name: "schema.jpg", width: 160, height: 120)
      assert_no_selector "trix-editor figure, trix-editor [data-trix-attachment]"
      assert_no_text tf("insert_image")
      assert_text "ADN"
      find("button[aria-label='#{t('components.modal.close')}']").click
    end
    assert_no_selector "turbo-frame#modal dialog[open]"
    assert_equal stored, Orm::ArticleImage.count
    assert page.evaluate_script("!performance.getEntriesByType('resource').some((entry) => /\\/teams\\/blog\\/images/.test(entry.name))")

    assert_no_page_reload do
      # 2. The shortcut leads to the list. On a phone, at 360 then 390 px, the titles of one wide word never make it scroll
      # sideways and the ⋮ menu is visible at once; neither does the modal, whose « Insérer une image » shows once Trix is
      # ready (C1). Back on a computer, the draft with its cover and two images of the text.
      within("#team_home_shortcuts") { click_on t("teams.homes.shortcuts.blog") }
      with_mobile_viewport(PHONES.first) do
        assert_selector "tr#article_#{long_article.public_id}", text: LONG_TITLE
        assert find("button[aria-controls=article-actions-#{long_article.public_id}]").visible?
        assert_no_horizontal_scroll "main", "tr#article_#{url_article.public_id} td:first-child", sizes: PHONES
        click_on "teams_articles_new"
        within("turbo-frame#modal dialog[open]") { editor }
        assert_selector "#article_insert_image"
        assert_no_horizontal_scroll
      end

      within "turbo-frame#modal dialog[open]" do
        fill_in "article[title]", with: "Réviser le BEPC en quatre semaines"
        fill_in "article[excerpt]", with: "Un plan simple, semaine après semaine."

        attach_file "article_cover_file", fixture("photos/photo.jpg")
        assert_selector "#article_cover_preview[src^='/blog/images/']", wait: UPLOAD_WAIT
        assert_no_selector "#article_cover_placeholder"
        assert_equal "", find("#article_cover_file").value, "le fichier ne part jamais avec le formulaire"
        # « Retirer la couverture » empties the field the form sends (a save without it deletes the cover: controller test).
        click_on tf("cover_remove")
        assert_selector "#article_cover_placeholder"
        assert_no_selector "#article_cover_preview"
        assert_no_selector "#article_cover_remove"
        assert_equal "", find("#article_cover_public_id", visible: :hidden).value
        assert page.evaluate_script("document.activeElement.id === 'article_cover_file'")
        # The cover chosen again is sent while the first image of the text is shrunk and sent. That image lands in the
        # text as the 12th key of the cover's text alternative is typed, then ends its upload while the rest is typed:
        # Trix redraws twice, and every key stays in the field, the focus too; the image goes where the cursor of the
        # text was (chantier tests-instables-cache-blog).
        attach_file "article_cover_file", fixture("photos/photo.jpg")
        editor.click
        editor.send_keys("Première semaine : les fractions.")
        insert_into_rich_text_on_keystroke("#article_cover_alt", after_keys: 12) do
          drop_generated_image(name: "tableau.jpg", width: 2000, height: 1500)
        end
        assert_selector "#article_cover_preview[src^='/blog/images/']", wait: UPLOAD_WAIT
        assert_selector "#article_cover_remove"
        find("#article_cover_alt").click
        type_like_a_human("Une élève révise à sa table")
        image1 = assert_image_row(1)
        assert_equal "Une élève révise à sa table", find("#article_cover_alt").value
        assert_equal "article_cover_alt", focused_element_id, "le focus reste dans le champ où l'on tape"
        assert_equal "Première semaine : les fractions.\uFFFC\n", rich_text_content, "le texte de l'article ne reçoit aucune touche"
        assert_selector "#article_body_upload_status", text: image_message("uploaded", number: 1), visible: :all
        within("##{image1}") { assert_text tf("image_alt_missing") }
        assert_selector "#article_insert_image"
        fill_in image1.sub("article_image_", "article_image_alts_"), with: "Le tableau des fractions de la première semaine"
        within("##{image1}") { assert_no_text tf("image_alt_missing") }

        editor.send_keys([ :control, :end ], "Deuxième semaine : la géométrie.")
        # The endpoint holds the upload until the test releases it: while it is in flight, Trix shows its progress bar on
        # the attachment and the editor is busy, however loaded the machine (a throttled network made this a race).
        # « Créer le brouillon » during the upload waits for it, then the article leaves with both images.
        hold_uploads do |release|
          # The other way round: the focus is in the text when the second image lands, at the first key typed after it;
          # the image goes in at the cursor, and the typing goes on after it, in the text.
          insert_into_rich_text_on_keystroke("trix-editor#article_body", after_keys: 1) do
            drop_generated_image(name: "portrait.jpg", width: 640, height: 480)
          end
          type_like_a_human(" ")
          assert_selector "trix-editor figure progress.attachment__progress", wait: UPLOAD_WAIT
          type_like_a_human("Une figure par jour.")
          assert_equal "article_body", focused_element_id
          assert_match(/la géométrie\. \uFFFCUne figure par jour\.\n\z/, rich_text_content)
          assert_selector "#article_editor[aria-busy=true]"
          mark_host_page
          click_on t("teams.articles.new.submit")
          assert_selector "#article_body_upload_status", text: image_message("waiting"), visible: :all
          assert_not Orm::Article.exists?(title: "Réviser le BEPC en quatre semaines"), "« Créer le brouillon » attend l'envoi en cours"
          release.call
        end
      end
      assert_toast t("teams.articles.create.created", title: "Réviser le BEPC en quatre semaines")
      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_no_selector "main[data-before-refresh]"

      article = Orm::Article.find_by!(title: "Réviser le BEPC en quatre semaines")
      images = article.body.body.attachables.grep(Orm::ArticleImage)
      assert_equal [ [ 1600, 1200 ], [ 640, 480 ] ], images.map { [ it.width, it.height ] }, "la photo de 2000 px est réduite à 1600"
      assert_equal [ "Le tableau des fractions de la première semaine", nil ], images.map(&:alt)
      assert_equal [ 64, 48, "Une élève révise à sa table" ], [ article.cover_image.width, article.cover_image.height, article.cover_alt ]
      row = "tr#article_#{article.public_id}"
      assert_selector "#teams_articles_list tr:first-child#article_#{article.public_id}", text: t("teams.articles.status.draft")

      # 3. Publication refused on image 2 (BL-13). In the modal, an image taken out of the text hides its row, undo brings
      # it back; the missing alternative is completed, Enter returns to the text; saved, then published (BL-07).
      click_menu_action row, t("teams.articles.menu.publish")
      within "turbo-frame#modal dialog[open]" do
        assert_selector "#article_publish_refused", text: t("teams.articles.edit_modal.refused_title")
        first_row = "#article_image_#{images.first.public_id}"
        second_row = "#article_image_#{images.second.public_id}"
        missing = "article_image_alts_#{images.second.public_id}"
        image_alt_blank = t("activemodel.errors.models.dtos/communication/article_input.image_alt_blank", number: 2)
        assert_selector "##{missing}_error", text: image_alt_blank
        assert_selector "##{missing}[aria-invalid=true]"
        editor
        assert_selector "trix-editor figure img[src='/blog/images/#{images.first.public_id}']"
        assert_no_selector "trix-editor figure .attachment__size, trix-editor figure .attachment__name"
        assert_selector "#article_images_title", text: "#{tf('images_title')} (2)"
        within(second_row) { assert_text "#{tf('image_alt_label')} 2" }

        select_first_image
        page.driver.browser.action.send_keys(:backspace).perform
        assert_selector first_row, visible: :hidden
        assert find("#{first_row} input", visible: :hidden).disabled?
        assert_selector "#article_images_title", text: "#{tf('images_title')} (1)"
        within(second_row) { assert_text "#{tf('image_alt_label')} 1" }

        editor.send_keys([ :control, "z" ])
        assert_selector first_row
        assert_not find("#{first_row} input").disabled?
        within(second_row) { assert_text "#{tf('image_alt_label')} 2" }

        alt = find("##{missing}")
        alt.fill_in(with: "La figure de géométrie de la deuxième semaine")
        within(second_row) { assert_no_text tf("image_alt_missing") }
        alt.send_keys(:enter)
        assert page.evaluate_script("document.activeElement.matches('trix-editor#article_body')"), "Entrée ramène au texte"

        mark_host_page
        click_on t("teams.articles.edit_modal.submit")
      end
      assert_toast t("teams.articles.update.updated", title: article.title)
      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_no_selector "main[data-before-refresh]"
      assert_selector row, text: t("teams.articles.status.draft")
      assert_equal images, article.reload.body.body.attachables.grep(Orm::ArticleImage), "l'image retirée puis remise reste dans le texte"
      assert_equal [ "Le tableau des fractions de la première semaine", "La figure de géométrie de la deuxième semaine" ],
                   images.map { it.reload.alt }

      click_menu_action row, t("teams.articles.menu.publish")
      assert_toast t("teams.articles.transition.published", title: article.title)
      assert_selector row, text: t("teams.articles.status.published")
      assert_equal "published", article.reload.status

      # 4. The public page shows the cover and both images, served by Lnclass (BL-14); then the article is archived.
      click_menu_action row, t("teams.articles.menu.view")
      assert_current_path blog_article_path(article.slug)
      assert_selector "h1", text: article.title
      [ article.cover_image, *images ].each do |image|
        assert_selector "img[src='/blog/images/#{image.public_id}'][alt]"
        assert image_loaded?("/blog/images/#{image.public_id}"), "l'image #{image.public_id} n'est pas servie"
      end
      page.go_back
      assert_current_path teams_articles_path

      click_menu_action row, t("teams.articles.menu.archive")
      assert_toast t("teams.articles.transition.archived", title: article.title)
      assert_selector row, text: t("teams.articles.status.archived")
    end
    assert_empty page.evaluate_script("window.cspViolations")

    # 5. A new article: every refused upload says why, and none is stored.
    stored = Orm::ArticleImage.count
    assert_no_page_reload do
      click_on "teams_articles_new"
      within "turbo-frame#modal dialog[open]" do
        fill_in "article[title]", with: "Un envoi qui échoue"
        editor.click
        # Trix's own attach button speaks French too, like the rest of its toolbar.
        assert_selector "trix-toolbar [data-trix-action=attachFiles][title='Insérer une image']", visible: :all
        assert_no_selector "trix-toolbar [title='Attach Files']", visible: :all
        editor.send_keys("Un texte.")

        # BL-12: a GIF (refused by the browser), a fake .jpg (by the server), noise too heavy even shrunk, an image from
        # a web page; the cover refuses a GIF too, its field invalid.
        attach_file(fixture("article_images/animation.gif")) { click_on tf("insert_image") }
        assert_selector "#article_body_upload_errors", text: refused("animation.gif", image_message("format"))
        attach_file(fixture("article_images/fake.jpg")) { click_on tf("insert_image") }
        unreadable = t("activemodel.errors.models.dtos/communication/article_image_input.attributes.file.unreadable")
        assert_selector "#article_body_upload_errors", text: refused("fake.jpg", unreadable), wait: UPLOAD_WAIT
        assert_no_selector "#article_body_upload_errors", text: "animation.gif"

        drop_generated_image(name: "bruit.jpg", width: 1400, height: 1400, noise: true)
        assert_selector "#article_body_upload_errors", text: refused("bruit.jpg", image_message("too_heavy")), wait: UPLOAD_WAIT

        paste_html_into_editor(%(<p>Vu ailleurs</p><img src="https://images.example.com/photo.jpg" width="20" height="20">))
        assert_selector "#article_body_upload_errors", text: refused("photo.jpg", image_message("web_image"))

        assert_no_selector "trix-editor figure"
        assert_selector "#article_images", visible: :hidden

        attach_file "article_cover_file", fixture("article_images/animation.gif")
        assert_selector "#article_cover_upload_error", text: refused("animation.gif", image_message("format"))
        assert_selector "#article_cover_file[aria-invalid=true]"
        assert_includes find("#article_cover_file")["aria-describedby"], "article_cover_upload_error"
        assert_selector "#article_cover_placeholder"
        assert_equal "", find("#article_cover_public_id", visible: :hidden).value
        assert_equal stored, Orm::ArticleImage.count, "rien n'est stocké (BL-12)"

        # An upload that never answers gives up after its delay (60 s in production; 300 ms here, through the value the
        # controllers read): the editor and the cover are free again.
        page.execute_script(<<~JS)
          document.querySelector("#article_editor").setAttribute("data-rich-text-editor-upload-timeout-value", "300")
          document.querySelector("#article_cover").setAttribute("data-communication--cover-picker-upload-timeout-value", "300")
        JS
        hold_uploads do
          attach_file(fixture("photos/portrait.jpg")) { click_on tf("insert_image") }
          attach_file "article_cover_file", fixture("photos/photo.jpg")
          assert_selector "#article_body_upload_errors", text: refused("portrait.jpg", image_message("failed")), wait: UPLOAD_WAIT
          assert_selector "#article_cover_upload_error", text: refused("photo.jpg", image_message("failed")), wait: UPLOAD_WAIT
          assert_no_selector "trix-editor figure"
          assert_no_selector "#article_editor[aria-busy]"
          assert_no_selector "#article_cover[aria-busy]"
        end
        # Back to the delay of production for what follows.
        page.execute_script(<<~JS)
          document.querySelector("#article_editor").removeAttribute("data-rich-text-editor-upload-timeout-value")
          document.querySelector("#article_cover").removeAttribute("data-communication--cover-picker-upload-timeout-value")
        JS

        # « Créer le brouillon » during an upload that fails (500) keeps the modal: nothing is saved, the refusal takes
        # the focus. The image of the text first, then the cover: same rule. The files differ from the ones above, so that
        # each refusal waited for is its own.
        hold_uploads do |release|
          attach_file(fixture("photos/photo.jpg")) { click_on tf("insert_image") }
          assert_selector "trix-editor figure progress.attachment__progress", wait: UPLOAD_WAIT
          click_on t("teams.articles.new.submit")
          assert_selector "#article_body_upload_status", text: image_message("waiting"), visible: :all
          release.call(500)
        end
        assert_selector "#article_body_upload_errors", text: refused("photo.jpg", image_message("failed")), wait: UPLOAD_WAIT
        assert_selector "#article_body_upload_errors", text: image_message("not_saved")
        assert_no_selector "#article_body_upload_status", text: image_message("waiting"), visible: :all
        assert page.evaluate_script("document.activeElement.id === 'article_body_upload_errors'"), "le refus prend le focus"
        assert_no_selector "trix-editor figure"

        hold_uploads do |release|
          attach_file "article_cover_file", fixture("photos/portrait.jpg")
          assert_selector "#article_cover[aria-busy=true]"
          click_on t("teams.articles.new.submit")
          assert_selector "#article_cover_status", text: image_message("waiting")
          release.call(500)
        end
        assert_selector "#article_cover_upload_error", text: refused("portrait.jpg", image_message("failed")), wait: UPLOAD_WAIT
        assert_selector "#article_cover_upload_error", text: image_message("not_saved")
        assert page.evaluate_script("document.activeElement.id === 'article_cover_upload_error'"), "le refus prend le focus"
        assert_selector "#article_cover_placeholder"
        assert_equal 3, Orm::Article.count, "rien n'est enregistré sans l'image"

        # The session expires while writing: the upload says so instead of blaming the connection (the text and the cover
        # at once: each has its own controller and its own message).
        Orm::Session.delete_all
        attach_file(fixture("photos/portrait.jpg")) { click_on tf("insert_image") }
        attach_file "article_cover_file", fixture("photos/photo.jpg")
        assert_selector "#article_body_upload_errors", text: refused("portrait.jpg", image_message("expired")), wait: UPLOAD_WAIT
        assert_selector "#article_cover_upload_error", text: refused("photo.jpg", image_message("expired")), wait: UPLOAD_WAIT
      end
      assert_selector "turbo-frame#modal dialog[open]"
    end
    assert_equal stored, Orm::ArticleImage.count, "aucun envoi refusé n'est stocké"

    # 6. A visitor (no session), on a phone, follows the shared link of the article archived in 4: « Cet article n'est plus
    # disponible ». A title of one word wider than the screen wraps on the article page and the cards of /blog, and the
    # 410 page does not scroll sideways either (C1, UDR-0066 §3): each page loaded once, measured at 360 then 390 px.
    page.reset!
    with_mobile_viewport do
      visit blog_article_path(Orm::Article.find_by!(title: "Réviser le BEPC en quatre semaines").slug)
      assert_selector "#article_gone h1", text: t("communication.articles.gone.title")
      assert_no_text "Réviser le BEPC"
      assert_no_horizontal_scroll "#article_gone h1", sizes: PHONES

      [ long_article, url_article ].each do |article|
        visit blog_article_path(article.slug)
        assert_selector "h1#article_title", text: article.title
        assert_no_horizontal_scroll "h1#article_title", sizes: PHONES
      end
      visit blog_path
      assert_no_horizontal_scroll "#blog_article_#{long_article.slug} h2", "#blog_article_#{url_article.slug} h2", sizes: PHONES
    end
  end

  # UDR-0067 §3.4.2, « le focus ne bouge pas » (chantier alt-couverture-perdu) : an image enters the text once the browser
  # has shrunk it. The author who went on writing elsewhere meanwhile keeps the focus, and what they type stays in their
  # field; the author writing in the text keeps the focus there.
  test "an image entering the text once shrunk leaves the focus where the author is writing" do
    visit teams_articles_path
    click_on "teams_articles_new"
    within "turbo-frame#modal dialog[open]" do
      assert_selector "#article_insert_image"
      # Dropped, then the cover text at once: the image is still being shrunk.
      assert_equal 0, drop_generated_image(name: "tableau.jpg", width: 2000, height: 1500, focus: "article_cover_alt"), "l'image est encore en réduction"
      assert_image_row(1)
      assert_equal "article_cover_alt", page.evaluate_script("document.activeElement.id"), "le focus reste au texte de remplacement"
      page.driver.browser.action.send_keys("Une élève").perform
      assert_equal "Une élève", find_field("article[cover_alt]").value
      assert_no_match(/élève/, page.evaluate_script("document.querySelector('trix-editor').editor.getDocument().toString()"))

      # Symmetric case: the author writing in the text keeps the focus there, and goes on writing in it.
      editor.send_keys([ :control, :end ], "Avant")
      drop_generated_image(name: "schema.jpg", width: 2000, height: 1500)
      assert_image_row(2)
      assert_equal "article_body", page.evaluate_script("document.activeElement.id")
      page.driver.browser.action.send_keys(" après").perform
      assert_match(/\uFFFC[^\uFFFC]*après/, page.evaluate_script("document.querySelector('trix-editor').editor.getDocument().toString()"), "après la seconde image")
      assert_equal "Une élève", find_field("article[cover_alt]").value
    end
  end

  private

  def record_csp_violations
    page.execute_script(<<~JS)
      window.cspViolations = []
      document.addEventListener("securitypolicyviolation", (event) => window.cspViolations.push(event.violatedDirective))
    JS
  end

  # The list is re-requested and morphed (turbo_stream.refresh): the morph drops this attribute, absent from the server's
  # HTML. A menu opened before the morph is done would be closed by it.
  def mark_host_page = page.execute_script("document.querySelector('main').dataset.beforeRefresh = 'true'")

  # At each size (the window's own by default; the current one first, to resize once less), the page never scrolls
  # sideways and each element named does not overflow its own box: the page is loaded once, the window resized under it.
  def assert_no_horizontal_scroll(*selectors, sizes: [ nil ])
    selectors.each { assert_selector it }
    current = page.current_window.size
    sizes.sort_by { it == current ? 0 : 1 }.each do |size|
      page.current_window.resize_to(*size) if size && size != current
      current = size || current
      widths = page.evaluate_script(<<~JS, selectors)
        [ window.innerWidth, [ document.documentElement, ...arguments[0].map((selector) => document.querySelector(selector)) ]
          .map((element) => [ element.scrollWidth, element.clientWidth ]) ]
      JS
      at, ((page_scroll, page_width), *boxes) = widths
      assert_operator page_scroll, :<=, page_width, "#{current_path} défile sur le côté à #{at} px"
      selectors.zip(boxes) { |selector, (scroll, width)| assert_operator scroll, :<=, width, "#{selector} déborde de sa boîte à #{at} px" }
    end
  end

  # The row of the panel « Images du texte » numbered n, waited for until the upload is done; its id.
  def assert_image_row(number)
    find("#article_images_list li:not([hidden])", text: "#{tf('image_alt_label')} #{number}", wait: UPLOAD_WAIT)[:id]
  end

  # The cursor on the first image of the text, as a click on it would put it.
  def select_first_image
    page.execute_script(<<~JS)
      const element = document.querySelector("trix-editor")
      const document_ = element.editor.getDocument()
      element.focus()
      element.editor.setSelectedRange(document_.getRangeOfAttachment(document_.getAttachments()[0]))
    JS
  end

  # The address of the page answers with an image (a lazy image of the page itself may not be loaded yet).
  def image_loaded?(src)
    page.evaluate_async_script(<<~JS, src)
      const [src, done] = arguments
      const image = new Image()
      image.src = src
      image.decode().then(() => done(image.naturalWidth > 0), () => done(false))
    JS
  end

  # The team endpoint holds every upload of the block until the test releases it: release.call lets the upload through,
  # release.call(500) answers that status instead. The state seen while an upload is under way is then certain, instead
  # of raced against a slowed network. Whatever is still held at the end of the block is let go.
  # The original action is kept in a local, not under an alias: a request let through just before the block ends still
  # finds it once the action is restored.
  def hold_uploads
    gate = Thread::Queue.new
    endpoint = Teams::ArticleImagesController
    original = endpoint.instance_method(:create)
    endpoint.define_method(:create) do
      answer = gate.pop
      answer == :pass ? original.bind_call(self) : head(answer || :service_unavailable)
    end
    yield ->(status = :pass) { gate << status }
  ensure
    gate.close
    endpoint.define_method(:create, original)
  end

  # A real drop, as the browser sends it, of an image drawn in the page: a gradient photo, or noise that no encoder
  # can bring under the weight ceiling. With focus, the element of that id takes the focus once Trix has handled the
  # drop (its own cursor goes into the text then), while the image is still being shrunk: as an author who goes on
  # writing elsewhere. → the number of images in the text at that moment.
  def drop_generated_image(name:, width:, height:, noise: false, focus: nil)
    page.evaluate_async_script(<<~JS, name, width, height, noise, focus)
      const [name, width, height, noise, focus, done] = arguments
      const canvas = Object.assign(document.createElement("canvas"), { width, height })
      const context = canvas.getContext("2d")
      if (noise) {
        const pixels = context.createImageData(width, height)
        for (let offset = 0; offset < pixels.data.length; offset += 65536) {
          crypto.getRandomValues(pixels.data.subarray(offset, offset + 65536))
        }
        for (let alpha = 3; alpha < pixels.data.length; alpha += 4) pixels.data[alpha] = 255
        context.putImageData(pixels, 0, 0)
      } else {
        const gradient = context.createLinearGradient(0, 0, width, height)
        gradient.addColorStop(0, "#1d4ed8")
        gradient.addColorStop(1, "#f59e0b")
        context.fillStyle = gradient
        context.fillRect(0, 0, width, height)
      }
      canvas.toBlob((blob) => {
        const transfer = new DataTransfer()
        transfer.items.add(new File([blob], name, { type: blob.type }))
        const editor = document.querySelector("trix-editor")
        if (focus) {
          editor.addEventListener("trix-file-accept", () => setTimeout(() => {
            document.getElementById(focus).focus()
            done(editor.editor.getDocument().getAttachments().length)
          }), { once: true })
        }
        for (const type of ["dragenter", "dragover", "drop"]) {
          editor.dispatchEvent(new DragEvent(type, { dataTransfer: transfer, bubbles: true, cancelable: true }))
        }
        if (!focus) done()
      }, "image/jpeg", 0.92)
    JS
  end

  # A paste of HTML copied from another site, as Chrome hands it to Trix (beforeinput « insertFromPaste »).
  def paste_html_into_editor(html)
    page.execute_script(<<~JS, html)
      const transfer = new DataTransfer()
      transfer.setData("text/html", arguments[0])
      document.querySelector("trix-editor").dispatchEvent(new InputEvent("beforeinput", { inputType: "insertFromPaste", dataTransfer: transfer, bubbles: true, cancelable: true }))
    JS
  end
end
