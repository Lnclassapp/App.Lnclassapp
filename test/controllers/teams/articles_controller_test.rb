require "test_helper"

# PRD blog, chemin nominal A (UDR-0065, ADR-0073): the team members admin and content manage the blog — list, modal to
# write a draft, publish, archive and republish from the ⋮ menu, each gesture audited (BL-07); everyone else receives
# 403 and nothing changes (BL-08); publishing an incomplete article reopens the modal in 422 naming what is missing
# (BL-09, BL-13); the list shows the reads « sans dédoublonnage » (BL-17).
class Teams::ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @content = create_team_member(team_role: "content", first_name: "Aya", last_name: "Traoré")
    @admin = create_team_member(team_role: "admin", first_name: "Koffi", last_name: "Yao")
  end

  def ta(key, **) = I18n.t("teams.articles.#{key}", **)
  def error(field, kind, **) = I18n.t("activemodel.errors.models.dtos/communication/article_input.attributes.#{field}.#{kind}", **)
  def image_alt_error(number) = I18n.t("activemodel.errors.models.dtos/communication/article_input.image_alt_blank", number:)
  def including(text) = /#{Regexp.escape(text)}/
  def audited(action) = Orm::AuditEvent.where(action:).pluck(:actor_id, :subject_type, :subject_id)

  def article_params(title: "Réviser le BEPC en 4 semaines", excerpt: "Un plan semaine par semaine.",
                     body: "<div>Commencez par les <strong>maths</strong>.</div>", signature: "team", **extra)
    { article: { title:, excerpt:, body:, signature:, **extra } }
  end

  test "BL-08: a field member, a teacher, a student and a school admin receive 403 on every route; nothing changes" do
    article = create_article(author: @content, status: "published")
    draft = create_article(author: @content, status: "draft")

    [ create_team_member(team_role: "field"), create_teacher, create_student, create_school_admin ].each do |outsider|
      sign_in_as outsider

      get teams_articles_path
      assert_response :forbidden
      get new_teams_article_path
      assert_response :forbidden
      get edit_teams_article_path(draft.public_id)
      assert_response :forbidden
      post teams_articles_path, params: article_params, as: :turbo_stream
      assert_response :forbidden
      patch teams_article_path(draft.public_id), params: article_params(title: "Autre"), as: :turbo_stream
      assert_response :forbidden
      patch publish_teams_article_path(draft.public_id), as: :turbo_stream
      assert_response :forbidden
      patch archive_teams_article_path(article.public_id), as: :turbo_stream
      assert_response :forbidden
      sign_out
    end

    assert_equal [ [ article.title, "published" ], [ draft.title, "draft" ] ], Orm::Article.order(:id).pluck(:title, :status)
    assert_empty Orm::AuditEvent.where("action LIKE 'article.%'")
  end

  test "BL-08: a visitor is sent to the sign-in, as on every team screen" do
    article = create_article(status: "draft")

    get teams_articles_path
    assert_redirected_to new_session_path
    patch publish_teams_article_path(article.public_id)
    assert_redirected_to new_session_path
    assert_equal "draft", article.reload.status
  end

  test "the empty list says so and offers « Nouvel article » in the modal" do
    sign_in_as @content

    get teams_articles_path

    assert_response :success
    assert_select "title", text: including(ta("index.page_title"))
    assert_select "h1", text: ta("index.title")
    assert_select "a[href='#{team_home_path}']", text: including(ta("index.back"))
    assert_select "a#teams_articles_new[href='#{new_teams_article_path}'][data-turbo-frame=modal]", text: including(ta("index.new_article"))
    assert_select "#teams_articles_total", text: ta("index.total", count: 0)
    assert_select "#teams_articles_empty", text: including(ta("index.empty_title")) do
      assert_select "a[href='#{new_teams_article_path}'][data-turbo-frame=modal]"
    end
    assert_select "table", 0
  end

  test "BL-17: the list shows every article, its state, date and reads « sans dédoublonnage », most recently updated first" do
    published = create_article(author: @content, title: "Réviser le BEPC", signature: "author", reads_count: 1234,
                               published_at: Time.zone.local(2026, 10, 5, 9))
    draft = create_article(author: @admin, status: "draft", title: "Brouillon")
    archived = create_article(author: @content, status: "archived", title: "Ancien", reads_count: 3,
                              archived_at: Time.zone.local(2026, 10, 8, 9))
    published.update_columns(updated_at: Time.zone.local(2026, 10, 10, 9))
    draft.update_columns(updated_at: Time.zone.local(2026, 10, 9, 9))
    archived.update_columns(updated_at: Time.zone.local(2026, 10, 1, 9))
    sign_in_as @admin

    get teams_articles_path

    assert_select "#teams_articles_total", text: ta("index.total", count: 3)
    assert_select "table caption.sr-only", text: ta("index.caption")
    assert_select "thead th", text: including(ta("index.columns.reads")) do
      assert_select "span.block", text: ta("index.columns.reads_note")
      assert_select "details", text: including(ta("index.reads_tip"))
    end
    assert_equal [ published, draft, archived ].map { "article_#{it.public_id}" }, css_select("tbody#teams_articles_list tr").pluck("id")
    assert_select "tr#article_#{published.public_id}" do
      assert_select "td span.font-medium", text: "Réviser le BEPC"
      assert_select "td span.block", text: "#{ta('article_row.written_by', author: 'Aya Traoré')} · #{ta('article_row.signed_author')}"
      assert_select "td", text: ta("status.published")
      assert_select "td", text: ta("article_row.published_on", date: "5 octobre 2026")
      assert_select "td.tabular-nums", text: "1 234"
      assert_select "button[aria-label=?]", ta("article_row.actions", title: "Réviser le BEPC")
      assert_select "#article_transitions_#{published.public_id} a[href='#{archive_teams_article_path(published.public_id)}']"
    end
    assert_select "tr#article_#{draft.public_id}" do
      assert_select "td span.block", text: including(ta("article_row.signed_team"))
      assert_select "td", text: ta("article_row.updated_on", date: "9 octobre 2026")
      assert_select "td.tabular-nums span[aria-hidden=true]", text: "—"
      assert_select "td.tabular-nums span.sr-only", text: ta("article_row.never_published")
    end
    assert_select "tr#article_#{archived.public_id}" do
      assert_select "td", text: ta("article_row.archived_on", date: "8 octobre 2026")
      assert_select "td.tabular-nums", text: "3"
    end
  end

  test "20 articles per page, the next ones on page 2" do
    author = @content
    21.times { create_article(author:, status: "draft") }
    sign_in_as @content

    get teams_articles_path
    assert_select "tbody#teams_articles_list tr", 20
    assert_select "a[href*='page=2']"

    get teams_articles_path(page: 2)
    assert_select "tbody#teams_articles_list tr", 1
  end

  test "the new form opens in the modal: title, excerpt and its counter, cover, editor in image mode, signature" do
    sign_in_as @content

    get new_teams_article_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#article-modal" do
      assert_select "p", text: including(ta("new.draft_notice"))
      assert_select "button#article-submit[type=submit][form=article-form]", text: ta("new.submit")
    end
    assert_select "link[rel=stylesheet][href*=trix]"
    assert_select "form#article-form[action='#{teams_articles_path}'][method=post]" do
      assert_select "input#article_title[name='article[title]'][maxlength='120'][required][data-autofocus-target=field]"
      assert_select "#article_title_hint", text: ta("form.title_hint_new", max: 120)
      assert_select "[data-controller=communication--character-count][data-communication--character-count-max-value='200']" do
        assert_select "textarea#article_excerpt[maxlength='200'][data-communication--character-count-target=input]"
        assert_select "p#article_excerpt_count[aria-hidden=true]", text: "0 / 200"
        assert_select "span.sr-only[aria-live=polite][data-communication--character-count-target=status]"
      end
      assert_select "fieldset#article_cover[data-controller=communication--cover-picker]" \
                    "[data-communication--cover-picker-upload-url-value='#{teams_article_images_path}']" do
        assert_select "legend", text: ta("form.cover_legend")
        assert_select "img#article_cover_preview[hidden]"
        assert_select "#article_cover_placeholder:not([hidden])", text: including(ta("form.cover_placeholder"))
        assert_select "input#article_cover_file[type=file][accept='image/jpeg,image/png,image/webp']:not([name])"
        assert_select "label[for=article_cover_file]", text: ta("form.cover_file_label")
        assert_select "button#article_cover_remove[hidden]"
        assert_select "#article_cover_file_hint", text: ta("form.cover_hint", max_side: 1600, max_bytes: "1 Mo")
        assert_select "p#article_cover_upload_error[role=alert][hidden]"
        assert_select "input#article_cover_public_id[type=hidden][name='article[cover_public_id]']"
        assert_select "input#article_cover_alt[name='article[cover_alt]'][maxlength='150']:not([required])"
      end
      assert_select "#article_editor[data-controller~=rich-text-editor][data-controller~=communication--image-alts]" \
                    "[data-rich-text-editor-attachments-value=true][data-rich-text-editor-upload-url-value='#{teams_article_images_path}']" do
        assert_select "label#article_body_label[for=article_body]"
        assert_select "button#article_insert_image[hidden][data-rich-text-editor-target=pickButton]", text: ta("form.insert_image")
        assert_select "input#article_image_files[type=file][multiple][hidden]:not([name])"
        assert_select "trix-editor#article_body[data-direct-upload-url=''][aria-describedby=article_body_hint]"
        assert_select "input[type=hidden][name='article[body]']"
        assert_select "#article_body_upload_errors[role=alert][hidden]"
        assert_select "#article_body_hint", text: ta("form.body_hint", max_count: 10, max_bytes: "1 Mo")
        assert_select "section#article_images[hidden]" do
          assert_select "ul#article_images_list li", 0
          assert_select "template[data-communication--image-alts-target=rowTemplate]"
        end
      end
      assert_select "input[type=radio][name='article[signature]'][value=team][checked]"
      assert_select "label", text: including("Aya Traoré")
      assert_select "select[name='article[status]']", 0
    end
    assert_select "#article_publish_refused", 0
  end

  test "BL-07: a content member creates a draft, its cited image attached with its alternative text, in Turbo Stream" do
    image = create_article_image
    sign_in_as @content

    post teams_articles_path, params: article_params(body: article_body_with(image),
                                                     image_alts: { image.public_id => "Une salle de classe" }), as: :turbo_stream

    assert_response :success
    article = Orm::Article.sole
    assert_equal [ "Réviser le BEPC en 4 semaines", "reviser-le-bepc-en-4-semaines", "draft", @content.id ],
                 [ article.title, article.slug, article.status, article.author_id ]
    assert_equal [ article.id, "Une salle de classe" ], [ image.reload.article_id, image.alt ]
    assert_equal [ [ @content.id, "Article", article.id ] ], audited("article.created")
    assert_select "turbo-stream[action=append][target=toasts]", text: including(ta("create.created", title: article.title))
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=refresh]:not([request-id])"
  end

  test "BL-07: an admin member creates a draft and a content member updates it; each gesture audited under its own actor" do
    sign_in_as @admin
    post teams_articles_path, params: article_params, as: :turbo_stream
    assert_response :success
    article = Orm::Article.sole

    sign_in_as @content
    patch teams_article_path(article.public_id), params: article_params(title: "Titre corrigé"), as: :turbo_stream
    assert_response :success

    assert_equal [ @admin.id, "Titre corrigé" ], [ article.reload.author_id, article.title ]
    assert_equal [ [ @admin.id, "Article", article.id ] ], audited("article.created")
    assert_equal [ [ @content.id, "Article", article.id ] ], audited("article.updated")
  end

  test "an invalid entry reopens the modal in 422, typed values, text and images kept" do
    image = create_article_image
    sign_in_as @content

    post teams_articles_path, params: article_params(title: " ", body: article_body_with(image),
                                                     image_alts: { image.public_id => "Une salle" })

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal #article_title_error", text: error(:title, :blank)
    assert_select "input#article_title[aria-invalid=true]"
    assert_select "textarea#article_excerpt", text: "Un plan semaine par semaine."
    assert_select "p#article_excerpt_count", text: "28 / 200"
    assert_select "input[type=hidden][name='article[body]'][value*=?]", "data-trix-attachment"
    assert_select "section#article_images:not([hidden])" do
      assert_select "li#article_image_#{image.public_id}[data-sgid='#{image.attachable_sgid}']" do
        assert_select "img[src='#{blog_image_path(image.public_id)}'][alt=''][loading=lazy]"
        assert_select "label[for=article_image_alts_#{image.public_id}] span[data-number]", text: "1"
        assert_select "input#article_image_alts_#{image.public_id}[name='article[image_alts][#{image.public_id}]'][value='Une salle']"
        assert_select "[data-communication--image-alts-target=missing][hidden]"
      end
    end
    assert_equal 0, Orm::Article.count
  end

  test "an unknown cover is refused in 422 under the cover" do
    sign_in_as @content

    post teams_articles_path, params: article_params(cover_public_id: "inconnue00000")

    assert_response :unprocessable_entity
    assert_select "#article_cover_public_id_error", text: error(:cover_public_id, :invalid)
    assert_select "input#article_cover_file[aria-invalid=true][aria-describedby~=article_cover_public_id_error]"
    assert_select "img#article_cover_preview[hidden]"
    assert_equal 0, Orm::Article.count
  end

  test "a text citing an attachment whose sgid does not verify is a 422 under the text; its images stay attached" do
    image = create_article_image
    article = create_article(author: @content, status: "draft", body: article_body_with(image))
    sign_in_as @content
    tampered = %(<action-text-attachment sgid="#{image.attachable_sgid}x" content-type="image/jpeg"></action-text-attachment>)

    patch teams_article_path(article.public_id), params: article_params(body: tampered)

    assert_response :unprocessable_entity
    assert_select "#article_body_error", text: error(:body, :image_unreadable)
    assert_equal article.id, image.reload.article_id
  end

  test "a slug taken twice by simultaneous creations is a 422 in the modal, never a 500; nothing is written" do
    create_article(title: "Réviser le BEPC en 4 semaines")
    sign_in_as @content
    Orm::Article.define_singleton_method(:exists?) { |*, **| false }

    assert_no_difference([ -> { Orm::Article.count }, -> { Orm::AuditEvent.count } ]) do
      post teams_articles_path, params: article_params
    end

    assert_response :unprocessable_entity
    assert_select "#article_base_error", text: I18n.t("activemodel.errors.messages.write_failed")
  ensure
    Orm::Article.singleton_class.remove_method(:exists?)
  end

  test "without Turbo, a creation redirects to the list with its notice" do
    sign_in_as @admin

    post teams_articles_path, params: article_params

    assert_redirected_to teams_articles_path
    assert_equal 303, response.status
    assert_equal ta("create.created", title: "Réviser le BEPC en 4 semaines"), flash[:notice]
  end

  test "the edit modal loads the saved article: fixed address, cover, images of the text with their alternative text" do
    cover = create_article_image
    image = create_article_image(alt: "Une salle de classe")
    article = create_article(author: @content, status: "published", title: "Réviser le BEPC", signature: "author",
                             cover:, cover_alt: "Des élèves", body: article_body_with(image))
    sign_in_as @admin

    get edit_teams_article_path(article.public_id), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog#article-modal" do
      assert_select "p", text: including(ta("edit_modal.published_notice"))
      assert_select "button#article-submit", text: ta("edit_modal.submit")
    end
    assert_select "form#article-form[action='#{teams_article_path(article.public_id)}']" do
      assert_select "input[name=_method][value=patch]"
      assert_select "input#article_title[value='Réviser le BEPC']"
      assert_select "#article_title_hint", text: ta("form.title_hint_edit", max: 120, path: blog_article_path(article.slug))
      assert_select "fieldset#article_cover[data-communication--cover-picker-upload-url-value=?]",
                    teams_article_images_path(article: article.public_id)
      assert_select "img#article_cover_preview[src='#{blog_image_path(cover.public_id)}']:not([hidden])"
      assert_select "#article_cover_placeholder[hidden]"
      assert_select "button#article_cover_remove:not([hidden])"
      assert_select "input#article_cover_public_id[value='#{cover.public_id}']"
      assert_select "input#article_cover_alt[value='Des élèves']"
      assert_select "input[type=hidden][name='article[body]'][value*=?]", image.attachable_sgid
      assert_select "section#article_images:not([hidden]) li#article_image_#{image.public_id}" do
        assert_select "input[value='Une salle de classe']"
      end
      # The signature names the article's author, even when another member edits it.
      assert_select "input[type=radio][value=author][checked]"
      assert_select "label", text: including("Aya Traoré")
    end
  end

  test "an unknown article: 404 on edit, update, publish and archive" do
    sign_in_as @content

    get edit_teams_article_path("inconnu0000000")
    assert_response :not_found
    patch teams_article_path("inconnu0000000"), params: article_params
    assert_response :not_found
    patch publish_teams_article_path("inconnu0000000")
    assert_response :not_found
    patch archive_teams_article_path("inconnu0000000")
    assert_response :not_found
  end

  test "BL-07: an update keeps the state, closes the modal and refreshes the list; audited" do
    article = create_article(author: @content, status: "draft", title: "Ancien titre")
    sign_in_as @admin

    patch teams_article_path(article.public_id), params: article_params(title: "Nouveau titre", excerpt: ""), as: :turbo_stream

    assert_response :success
    assert_equal [ "Nouveau titre", article.slug, "draft", nil ], article.reload.then { [ it.title, it.slug, it.status, it.excerpt ] }
    assert_equal [ [ @admin.id, "Article", article.id ] ], audited("article.updated")
    assert_select "turbo-stream[target=toasts]", text: including(ta("update.updated", title: "Nouveau titre"))
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=refresh]"
  end

  test "BL-10: a published article whose title is corrected keeps its address, which still answers 200; a third same title gets -3" do
    sign_in_as @content
    2.times { post teams_articles_path, params: article_params(title: "Réviser le BEPC") }
    article = Orm::Article.find_by!(slug: "reviser-le-bepc")
    article.update_columns(status: "published", published_at: 1.day.ago)

    patch teams_article_path(article.public_id), params: article_params(title: "Réviser le BEPC en 6 semaines"), as: :turbo_stream
    post teams_articles_path, params: article_params(title: "Réviser le BEPC")

    assert_equal "reviser-le-bepc", article.reload.slug
    assert_equal %w[reviser-le-bepc reviser-le-bepc-2 reviser-le-bepc-3], Orm::Article.order(:id).pluck(:slug)
    get blog_article_path("reviser-le-bepc")
    assert_response :ok
    assert_select "h1", text: "Réviser le BEPC en 6 semaines"
    get blog_article_path("reviser-le-bepc-en-6-semaines")
    assert_response :not_found
  end

  test "removing the cover and an image of the text in one save deletes both, without a 500" do
    cover = create_article_image
    image = create_article_image(alt: "Un schéma")
    article = create_article(author: @content, status: "draft", cover:, cover_alt: "Des élèves en classe",
                             body: article_body_with(image))
    sign_in_as @content

    patch teams_article_path(article.public_id), params: article_params(title: article.title, cover_public_id: ""), as: :turbo_stream

    assert_response :success
    assert_nil article.reload.cover_image
    assert_not Orm::ArticleImage.exists?(cover.id)
    assert_not Orm::ArticleImage.exists?(image.id)
  end

  test "an update of a published article says it is online; emptying its excerpt is refused in 422" do
    article = create_article(author: @content, status: "published", title: "En ligne")
    sign_in_as @content

    patch teams_article_path(article.public_id), params: article_params(title: "En ligne"), as: :turbo_stream
    assert_select "turbo-stream[target=toasts]", text: including(ta("update.updated_live", title: "En ligne"))

    patch teams_article_path(article.public_id), params: article_params(title: "En ligne", excerpt: " ")
    assert_response :unprocessable_entity
    assert_select "#article_excerpt_error", text: error(:excerpt, :blank)
    assert_select "dialog#article-modal", text: including(ta("edit_modal.status_notice"))
    assert_equal "Un plan semaine par semaine.", article.reload.excerpt
  end

  test "without Turbo, an update redirects to the list with its notice" do
    article = create_article(author: @content, status: "draft")
    sign_in_as @content

    patch teams_article_path(article.public_id), params: article_params(title: "Titre corrigé")

    assert_redirected_to teams_articles_path
    assert_equal ta("update.updated", title: "Titre corrigé"), flash[:notice]
  end

  test "BL-07: content and admin publish, archive and republish; the row is morphed, each gesture audited" do
    [ @content, @admin ].each do |member|
      article = create_article(author: @content, status: "draft", title: "Article de #{member.first_name}")
      sign_in_as member

      patch publish_teams_article_path(article.public_id), as: :turbo_stream
      assert_response :success
      assert_select "turbo-stream[target=toasts]", text: including(ta("transition.published", title: article.title))
      assert_select "turbo-stream[action=replace][target=article_#{article.public_id}][method=morph]" do
        assert_select "template tr#article_#{article.public_id}", text: including(ta("status.published"))
      end
      # A first publication some days ago, for the republication to keep it.
      first_published = Time.zone.local(2026, 9, 28, 9)
      article.update_columns(published_at: first_published)

      patch archive_teams_article_path(article.public_id), as: :turbo_stream
      assert_select "turbo-stream[target=toasts]", text: including(ta("transition.archived", title: article.title))
      assert_equal "archived", article.reload.status

      patch publish_teams_article_path(article.public_id), as: :turbo_stream
      assert_select "turbo-stream[target=toasts]", text: including(ta("transition.republished", title: article.title))
      # BL-11: the same address, at the date of the first publication.
      assert_equal [ "published", first_published, nil ], article.reload.then { [ it.status, it.published_at, it.archived_at ] }

      assert_equal %w[article.published article.archived article.published],
                   Orm::AuditEvent.where(subject_type: "Article", subject_id: article.id, actor_id: member.id).order(:id).pluck(:action)
      sign_out
    end
  end

  test "BL-09: publishing a draft without excerpt reopens the edit modal in 422, the excerpt named; it stays a draft" do
    article = create_article(author: @content, status: "draft", excerpt: nil, title: "Sans résumé")
    sign_in_as @content

    patch publish_teams_article_path(article.public_id), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[target=toasts]", 0
    assert_select "turbo-stream[action=update][target=modal]" do
      assert_select "dialog#article-modal #article_publish_refused[role=alert]" do
        assert_select "p.font-semibold", text: ta("edit_modal.refused_title")
        assert_select "li", text: error(:excerpt, :blank)
      end
      assert_select "form#article-form[action='#{teams_article_path(article.public_id)}']"
      assert_select "#article_excerpt_error", text: error(:excerpt, :blank)
      assert_select "textarea#article_excerpt[aria-invalid=true]"
    end
    assert_select "turbo-stream[action=replace][target=article_#{article.public_id}][method=morph]",
                  text: including(ta("status.draft"))
    assert_equal "draft", article.reload.status
    assert_empty audited("article.published")
  end

  test "BL-13: an image of the text without alternative text is named by its number, its row invalid" do
    first = create_article_image(alt: "Une salle")
    second = create_article_image
    article = create_article(author: @content, status: "draft", body: article_body_with(first, second))
    sign_in_as @admin

    patch publish_teams_article_path(article.public_id), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "#article_publish_refused li", text: image_alt_error(2)
    assert_select "li#article_image_#{second.public_id}" do
      assert_select "input#article_image_alts_#{second.public_id}[aria-invalid=true]" \
                    "[aria-describedby='article_image_alts_#{second.public_id}_hint article_image_alts_#{second.public_id}_error']"
      assert_select "#article_image_alts_#{second.public_id}_error", text: image_alt_error(2)
      assert_select "[data-communication--image-alts-target=missing]:not([hidden])", text: ta("form.image_alt_missing")
    end
    assert_select "li#article_image_#{first.public_id} input[aria-invalid]", 0
    assert_equal "draft", article.reload.status
  end

  test "without Turbo, a refused publication redirects to the edit modal with its alert" do
    article = create_article(author: @content, status: "draft", excerpt: nil)
    sign_in_as @content

    patch publish_teams_article_path(article.public_id)

    assert_redirected_to edit_teams_article_path(article.public_id)
    assert_equal ta("publish.refused_fallback"), flash[:alert]
  end

  test "a transition already made is a conflict: 422, error toast, the row re-rendered in its state" do
    article = create_article(author: @content, status: "published", title: "Déjà en ligne")
    sign_in_as @content

    patch publish_teams_article_path(article.public_id), as: :turbo_stream

    assert_response :unprocessable_entity
    assert_select "turbo-stream[target=toasts]", text: including(ta("transition.conflict", title: "Déjà en ligne"))
    assert_select "turbo-stream[action=replace][target=article_#{article.public_id}]", text: including(ta("status.published"))

    draft = create_article(author: @content, status: "draft", title: "Brouillon")
    patch archive_teams_article_path(draft.public_id)
    assert_redirected_to teams_articles_path
    assert_equal ta("transition.conflict", title: "Brouillon"), flash[:alert]
  end

  test "without Turbo, a transition redirects to the list with its notice" do
    article = create_article(author: @content, status: "draft", title: "Prêt")
    sign_in_as @content

    patch publish_teams_article_path(article.public_id)

    assert_redirected_to teams_articles_path
    assert_equal ta("transition.published", title: "Prêt"), flash[:notice]
  end
end
