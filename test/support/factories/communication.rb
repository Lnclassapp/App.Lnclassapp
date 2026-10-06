# Announcements (ADR-0045, ADR-0078, ADR-0081): a message of any author, status and theme, with a base illustration or a
# drawing of the team, its targeted classrooms, a dismissal; a drawing of the team.
# Blog articles and their images (ADR-0074), written as the application writes them: Orm:: for the article, the image
# store adapter for the file, as attach_photo does. Shared by the lots A, B, D, E and F of the blog chantier.
module Factories
  module Communication
    ActiveSupport::TestCase.include(self)

    # Returns the Orm::Message. ends_at: published_at + 30 days by default, nil for a draft. A message for classrooms
    # takes the school of its first classroom; a withdrawn one, a moderator of the team unless `withdrawn_by:` is given.
    # illustration: a base key, or an Orm::MessageIllustration of the team (illustration_id set, the key left nil).
    def create_message(author:, title: "Devoirs communs", body: "Ils commencent lundi.", audience: "students", school: nil,
                       classrooms: [], status: "published", published_at: 1.hour.ago, ends_at: nil, theme: "ciel",
                       illustration: "info", edited_at: nil, withdrawn_by: nil, **attributes)
      school ||= classrooms.first&.school if audience == "classrooms"
      ends_at ||= published_at + Entities::Communication::Message::DURATION unless status == "draft" || published_at.nil?
      if status == "withdrawn"
        withdrawn_by ||= create_team_member(second_factor: false)
        attributes[:withdrawn_at] ||= Time.current
      end
      library = illustration if illustration.is_a?(Orm::MessageIllustration)
      Orm::Message.create!(author:, title:, body:, audience:, school:, status:, published_at:, ends_at:, theme:,
                           illustration: (illustration unless library), library_illustration: library, edited_at:,
                           withdrawn_by:, **attributes).tap do |message|
        classrooms.each { |classroom| Orm::MessageClassroom.create!(message:, classroom:) }
      end
    end

    def dismiss_message(message:, user:, at: Time.current)
      Orm::MessageDismissal.create!(message:, user:, dismissed_at: at)
    end

    # ADR-0081 §4.3: a drawing of the team, stored as the SVG reading rebuilds it (Entities::Communication::Illustration
    # format: one rectangle by default). Returns the Orm::MessageIllustration.
    ILLUSTRATION_RECT = { "name" => "rect", "attributes" => { "x" => "8", "y" => "8", "width" => "48", "height" => "48", "rx" => "6" },
                          "children" => [] }.freeze

    def create_illustration(name:, created_by:, view_box: "0 0 64 64", shapes: [ ILLUSTRATION_RECT ], retired_at: nil, **attributes)
      Orm::MessageIllustration.create!(name:, created_by:, view_box:, shapes:, retired_at:, **attributes)
    end

    # A published article by default, signed « L'équipe Lnclass », with its excerpt and dates (ADR-0035). The cover and
    # the images that the body cites are attached to the article, as ArticleRepository attaches them on save.
    def create_article(author: create_team_member(team_role: "content", second_factor: false), status: "published",
                       title: "Article #{factory_sequence}", excerpt: "Le résumé de l'article.",
                       body: "<div>Le texte de l'article.</div>", signature: "team", cover: nil,
                       cover_alt: ("La couverture de l'article" if cover), published_at: nil, archived_at: nil, **attributes)
      dates = factory_publication(status)
      Orm::Article.create!(author:, status:, title:, excerpt:, body:, signature:, cover_image: cover, cover_alt:,
                           published_at: published_at || dates[:published_at], archived_at: archived_at || dates[:archived_at],
                           **attributes).tap do |article|
        cited = article.body.body.attachables.grep(Orm::ArticleImage).map(&:id)
        Orm::ArticleImage.where(id: [ *cited, cover&.id ].compact, article_id: nil).update_all(article_id: article.id)
      end
    end

    # A checked image without metadata, stored by Repositories::Communication::ArticleImageStore (article_id NULL until
    # an article cites it). fixture: a path under test/fixtures/files (JPEG, PNG or WebP, 64 × 48 px by default).
    def create_article_image(article: nil, alt: nil, fixture: "photos/photo.jpg", created_at: nil)
      input = Dtos::Communication::ArticleImageInput.new(file: StringIO.new(file_fixture(fixture).binread))
      raise ArgumentError, "#{fixture} n'est pas une image d'article : #{input.errors.full_messages}" unless input.valid?

      stored = Repositories::Communication::ArticleImageStore.new.store(data: input.data, content_type: input.content_type,
                                                                        width: input.width, height: input.height)
      Orm::ArticleImage.find_by!(public_id: stored.public_id).tap do |image|
        columns = { article_id: article&.id, alt:, created_at: }.compact
        image.update_columns(columns) if columns.any?
      end
    end

    # The HTML of an article body as Action Text stores it: a paragraph, then each image cited by its sgid.
    def article_body_with(*images, text: "Le texte de l'article.")
      attachments = images.map do |image|
        %(<action-text-attachment sgid="#{image.attachable_sgid}" content-type="#{image.content_type}" ) +
          %(width="#{image.width}" height="#{image.height}"></action-text-attachment>)
      end
      "<div>#{text}</div>#{attachments.join}"
    end
  end
end
