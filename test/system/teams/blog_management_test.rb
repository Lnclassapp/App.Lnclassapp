require "application_system_test_case"

# UDR-0065 §3.10, ADR-0073 §7 — the team writes the blog in the browser, end to end (chantier blog, nominal path A):
# a Contenu member opens « Blog » from the team home, writes a draft with a cover and two images in its text (shrunk in
# the browser, sent to the team endpoint while Trix shows its progress bar), leaves one text alternative empty, sees the
# publication refused on that image (BL-13), completes it, publishes (BL-07), reads the public page with its images
# served by Lnclass (BL-14), archives, puts it back online, and a visitor meets « Cet article n'est plus disponible ».
# Error paths: a GIF, a fake .jpg, an image too heavy even shrunk and an image pasted from a web page are refused with
# their reason (BL-12). The course editor still refuses any image (BL-15). Everything under the strict CSP.
class Teams::BlogManagementTest < ApplicationSystemTestCase
  # Shrinking a 4000 px photo, then sending it, under a loaded full suite.
  UPLOAD_WAIT = 20
  # Bytes per second offered to an upload while the test watches the progress bar and the held « Enregistrer ».
  SLOW_UPLOAD = 8_000
  IMAGE = Entities::Communication::ArticleImage

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

  test "a draft with a cover and two shrunk images, refused then published, read in public, archived, then gone" do
    assert_no_page_reload do
      # 1. The shortcut, the empty list, the draft with its cover and two images of the text.
      within("#team_home_shortcuts") { click_on t("teams.homes.shortcuts.blog") }
      assert_selector "#teams_articles_empty", text: t("teams.articles.index.empty_title")
      click_on "teams_articles_new"

      within "turbo-frame#modal dialog[open]" do
        fill_in "article[title]", with: "Réviser le BEPC en quatre semaines"
        fill_in "article[excerpt]", with: "Un plan simple, semaine après semaine."

        attach_file "article_cover_file", fixture("photos/photo.jpg")
        assert_selector "#article_cover_preview[src^='/blog/images/']", wait: UPLOAD_WAIT
        assert_no_selector "#article_cover_placeholder"
        assert_selector "#article_cover_remove"
        assert_equal "", find("#article_cover_file").value, "le fichier ne part jamais avec le formulaire"
        fill_in "article[cover_alt]", with: "Une élève révise à sa table"

        editor.click
        editor.send_keys("Première semaine : les fractions.")
        with_slow_upload do
          drop_generated_image(name: "tableau.jpg", width: 4000, height: 3000)
          # The upload goes slowly: Trix shows its progress bar on the attachment, the editor is busy.
          assert_selector "trix-editor figure progress.attachment__progress", wait: UPLOAD_WAIT
          assert_selector "#article_editor[aria-busy=true]"
        end
        image1 = assert_image_row(1)
        assert_selector "#article_body_upload_status", text: image_message("uploaded", number: 1), visible: :all
        within("##{image1}") { assert_text tf("image_alt_missing") }
        assert_selector "#article_insert_image"
        fill_in image1.sub("article_image_", "article_image_alts_"), with: "Le tableau des fractions de la première semaine"
        within("##{image1}") { assert_no_text tf("image_alt_missing") }

        editor.send_keys([ :control, :end ], "Deuxième semaine : la géométrie.")
        # « Créer le brouillon » during an upload waits for it, then the article leaves with both images.
        with_slow_upload do
          attach_file(fixture("photos/portrait.jpg")) { click_on tf("insert_image") }
          assert_selector "trix-editor figure progress.attachment__progress", wait: UPLOAD_WAIT
          mark_host_page
          click_on t("teams.articles.new.submit")
          assert_selector "#article_body_upload_status", text: image_message("waiting"), visible: :all
        end
      end
      assert_toast t("teams.articles.create.created", title: "Réviser le BEPC en quatre semaines")
      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_no_selector "main[data-before-refresh]"

      article = Orm::Article.sole
      images = article.body.body.attachables.grep(Orm::ArticleImage)
      assert_equal [ [ 1600, 1200 ], [ 640, 480 ] ], images.map { [ it.width, it.height ] }, "la photo de 4000 px est réduite à 1600"
      assert_equal [ "Le tableau des fractions de la première semaine", nil ], images.map(&:alt)
      assert_equal [ 64, 48, "Une élève révise à sa table" ], [ article.cover_image.width, article.cover_image.height, article.cover_alt ]
      row = "tr#article_#{article.public_id}"
      assert_selector "#teams_articles_list tr:first-child#article_#{article.public_id}", text: t("teams.articles.status.draft")

      # 2. Publication refused on image 2 (BL-13), completed, saved, published (BL-07).
      click_menu_action row, t("teams.articles.menu.publish")
      within "turbo-frame#modal dialog[open]" do
        assert_selector "#article_publish_refused", text: t("teams.articles.edit_modal.refused_title")
        missing = "article_image_alts_#{images.second.public_id}"
        image_alt_blank = t("activemodel.errors.models.dtos/communication/article_input.image_alt_blank", number: 2)
        assert_selector "##{missing}_error", text: image_alt_blank
        assert_selector "##{missing}[aria-invalid=true]"
        assert_selector "trix-editor figure img[src='/blog/images/#{images.first.public_id}']"
        fill_in missing, with: "La figure de géométrie de la deuxième semaine"
        mark_host_page
        click_on t("teams.articles.edit_modal.submit")
      end
      assert_toast t("teams.articles.update.updated", title: article.title)
      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_no_selector "main[data-before-refresh]"
      assert_selector row, text: t("teams.articles.status.draft")

      click_menu_action row, t("teams.articles.menu.publish")
      assert_toast t("teams.articles.transition.published", title: article.title)
      assert_selector row, text: t("teams.articles.status.published")
      assert_equal "published", article.reload.status

      # 3. The public page shows the cover and both images, served by Lnclass (BL-14); archive, put back online.
      click_menu_action row, t("teams.articles.menu.view")
      assert_current_path blog_article_path(article.slug)
      assert_selector "h1", text: article.title
      [ article.cover_image, *images ].each do |image|
        assert_selector "img[src='/blog/images/#{image.public_id}'][alt]"
        assert image_loaded?("/blog/images/#{image.public_id}"), "l'image #{image.public_id} n'est pas servie"
      end
      assert_selector "img[alt='La figure de géométrie de la deuxième semaine'][loading=lazy]"
      page.go_back
      assert_current_path teams_articles_path

      click_menu_action row, t("teams.articles.menu.archive")
      assert_toast t("teams.articles.transition.archived", title: article.title)
      assert_selector row, text: t("teams.articles.status.archived")
      click_menu_action row, t("teams.articles.menu.republish")
      assert_toast t("teams.articles.transition.republished", title: article.title)
      assert_selector row, text: t("teams.articles.status.published")
      click_menu_action row, t("teams.articles.menu.archive")
      assert_selector row, text: t("teams.articles.status.archived")
    end
    assert_empty page.evaluate_script("window.cspViolations")

    # A visitor follows the shared link of the archived article.
    sign_out
    visit blog_article_path(Orm::Article.sole.slug)
    assert_selector "#article_gone h1", text: t("communication.articles.gone.title")
    assert_no_text "Réviser le BEPC"
  end

  test "a GIF, a fake .jpg, an image too heavy even shrunk and an image from a web page are refused with their reason" do
    visit teams_articles_path
    assert_no_page_reload do
      click_on "teams_articles_new"
      within "turbo-frame#modal dialog[open]" do
        editor.click
        editor.send_keys("Un texte.")

        attach_file(fixture("article_images/animation.gif")) { click_on tf("insert_image") }
        assert_selector "#article_body_upload_errors", text: refused("animation.gif", image_message("format"))
        attach_file(fixture("article_images/fake.jpg")) { click_on tf("insert_image") }
        unreadable = t("activemodel.errors.models.dtos/communication/article_image_input.attributes.file.unreadable")
        assert_selector "#article_body_upload_errors", text: refused("fake.jpg", unreadable), wait: UPLOAD_WAIT
        assert_no_selector "#article_body_upload_errors", text: "animation.gif"

        drop_generated_image(name: "bruit.png", width: 1600, height: 1600, noise: true)
        assert_selector "#article_body_upload_errors", text: refused("bruit.png", image_message("too_heavy")), wait: UPLOAD_WAIT

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
      end
    end
    assert_equal 0, Orm::ArticleImage.count, "rien n'est stocké (BL-12)"
  end

  test "« Créer le brouillon » during an upload that fails keeps the modal: nothing is saved, the refusal takes the focus" do
    visit teams_articles_path
    assert_no_page_reload do
      click_on "teams_articles_new"
      within "turbo-frame#modal dialog[open]" do
        fill_in "article[title]", with: "Un envoi qui échoue"
        editor.click
        editor.send_keys("Un texte.")

        # An image of the text: its upload answers 500 while « Créer le brouillon » waits for it.
        hold_uploads do |release|
          attach_file(fixture("photos/portrait.jpg")) { click_on tf("insert_image") }
          assert_selector "trix-editor figure progress.attachment__progress", wait: UPLOAD_WAIT
          click_on t("teams.articles.new.submit")
          assert_selector "#article_body_upload_status", text: image_message("waiting"), visible: :all
          release.call(500)
        end
        assert_selector "#article_body_upload_errors", text: refused("portrait.jpg", image_message("failed")), wait: UPLOAD_WAIT
        assert_selector "#article_body_upload_errors", text: image_message("not_saved")
        assert_no_selector "#article_body_upload_status", text: image_message("waiting"), visible: :all
        assert page.evaluate_script("document.activeElement.id === 'article_body_upload_errors'"), "le refus prend le focus"
        assert_no_selector "trix-editor figure"

        # The cover: same rule.
        hold_uploads do |release|
          attach_file "article_cover_file", fixture("photos/photo.jpg")
          assert_selector "#article_cover[aria-busy=true]"
          click_on t("teams.articles.new.submit")
          assert_selector "#article_cover_status", text: image_message("waiting")
          release.call(500)
        end
        assert_selector "#article_cover_upload_error", text: refused("photo.jpg", image_message("failed")), wait: UPLOAD_WAIT
        assert_selector "#article_cover_upload_error", text: image_message("not_saved")
        assert page.evaluate_script("document.activeElement.id === 'article_cover_upload_error'"), "le refus prend le focus"
        assert_selector "#article_cover_placeholder"
      end
      assert_selector "turbo-frame#modal dialog[open]"
    end
    assert_equal 0, Orm::Article.count, "rien n'est enregistré sans l'image"
  end

  test "editing: an image taken out of the text hides its row, undo brings it back, Enter returns to the text, the cover clears" do
    first = create_article_image(alt: "Le premier schéma")
    second = create_article_image(fixture: "photos/photo.png")
    article = create_article(author: @member, status: "draft", cover: create_article_image, body: article_body_with(first, second))
    first_row = "#article_image_#{first.public_id}"
    second_row = "#article_image_#{second.public_id}"
    visit teams_articles_path

    assert_no_page_reload do
      click_menu_action "tr#article_#{article.public_id}", t("teams.articles.menu.edit")
      within "turbo-frame#modal dialog[open]" do
        editor
        assert_selector "#article_cover_preview[src='/blog/images/#{article.cover_image.public_id}']"
        assert_selector "#article_images_title", text: "#{tf('images_title')} (2)"
        within(second_row) { assert_text "#{tf('image_alt_label')} 2" }
        assert_no_selector "trix-editor figure .attachment__size, trix-editor figure .attachment__name"

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

        alt = find("#article_image_alts_#{second.public_id}")
        alt.fill_in(with: "Le second schéma")
        within(second_row) { assert_no_text tf("image_alt_missing") }
        alt.send_keys(:enter)
        assert page.evaluate_script("document.activeElement.matches('trix-editor#article_body')"), "Entrée ramène au texte"

        mark_host_page
        click_on t("teams.articles.edit_modal.submit")
      end
      assert_toast t("teams.articles.update.updated", title: article.title)
      assert_no_selector "main[data-before-refresh]"

      # « Retirer la couverture » empties the field the form sends; saving leaves the article without cover.
      click_menu_action "tr#article_#{article.public_id}", t("teams.articles.menu.edit")
      within "turbo-frame#modal dialog[open]" do
        click_on tf("cover_remove")
        assert_selector "#article_cover_placeholder"
        assert_no_selector "#article_cover_preview"
        assert_no_selector "#article_cover_remove"
        assert_equal "", find("#article_cover_public_id", visible: :hidden).value
        assert page.evaluate_script("document.activeElement.id === 'article_cover_file'")
        click_on t("teams.articles.edit_modal.submit")
      end
      assert_toast t("teams.articles.update.updated", title: article.title)
      assert_no_selector "turbo-frame#modal dialog[open]"
    end
    assert_nil article.reload.cover_image

    article.reload
    assert_equal [ first, second ], article.body.body.attachables.grep(Orm::ArticleImage)
    assert_equal [ "Le premier schéma", "Le second schéma" ], [ first.reload.alt, second.reload.alt ]
  end

  test "the course editor still refuses any image: no button, a dropped photo never reaches the server (BL-15)" do
    create_course(name: "Génétique et évolution")
    visit teams_imports_path
    open_in_modal(new_teams_course_path)
    within "turbo-frame#modal dialog[open]" do
      editor = find_rich_text_editor
      editor.click
      editor.send_keys("ADN")
      drop_generated_image(name: "schema.jpg", width: 800, height: 600)
      assert_no_selector "trix-editor figure, trix-editor [data-trix-attachment]"
      assert_no_text tf("insert_image")
      assert_text "ADN"
    end
    assert_equal 0, Orm::ArticleImage.count
    assert page.evaluate_script("!performance.getEntriesByType('resource').some((entry) => /\\/teams\\/blog\\/images/.test(entry.name))")
  end

  test "on a phone, the list and the modal never scroll sideways and the ⋮ menu is visible at once" do
    article = create_article(author: @member, title: "Un article", cover: create_article_image)
    with_mobile_viewport do
      visit teams_articles_path
      assert_selector "button[aria-controls=article-actions-#{article.public_id}]"
      assert find("button[aria-controls=article-actions-#{article.public_id}]").visible?
      assert_no_horizontal_scroll

      click_on "teams_articles_new"
      within("turbo-frame#modal dialog[open]") { find_rich_text_editor("trix-editor#article_body") }
      assert_selector "#article_insert_image"
      assert_no_horizontal_scroll
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

  def assert_no_horizontal_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "la page défile sur le côté"
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
  def hold_uploads
    gate = Thread::Queue.new
    endpoint = Teams::ArticleImagesController
    endpoint.alias_method :create_unheld, :create
    endpoint.define_method(:create) do
      answer = gate.pop
      answer == :pass ? create_unheld : head(answer || :service_unavailable)
    end
    yield ->(status = :pass) { gate << status }
  ensure
    gate.close
    endpoint.alias_method :create, :create_unheld
    endpoint.remove_method :create_unheld
  end

  # Chrome throttles the uploads of the block: the progress bar and the held submit can be seen.
  def with_slow_upload
    page.driver.browser.network_conditions = { offline: false, latency: 0, download_throughput: -1, upload_throughput: SLOW_UPLOAD }
    yield
  ensure
    page.driver.browser.network_conditions = { offline: false, latency: 0, download_throughput: -1, upload_throughput: -1 }
  end

  # A real drop, as the browser sends it, of an image drawn in the page: a gradient photo, or noise that no encoder
  # can bring under the weight ceiling.
  def drop_generated_image(name:, width:, height:, noise: false)
    page.evaluate_async_script(<<~JS, name, width, height, noise)
      const [name, width, height, noise, done] = arguments
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
        for (const type of ["dragenter", "dragover", "drop"]) {
          editor.dispatchEvent(new DragEvent(type, { dataTransfer: transfer, bubbles: true, cancelable: true }))
        }
        done()
      }, noise ? "image/png" : "image/jpeg", 0.92)
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
