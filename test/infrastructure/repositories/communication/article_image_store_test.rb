require "test_helper"

# ADR-0073 §4.4 : une image d'article est une ligne d'article_images et son fichier sur le service Active Storage (le
# bucket en production), né analysé ; elle se lit avec l'état de son article ; une orpheline de plus de 48 h est purgée.
module Repositories
  module Communication
    class ArticleImageStoreTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      Port = Ports::Communication::ArticleImageStorePort

      setup do
        @store = ArticleImageStore.new
        @webp = file_fixture("photos/photo_lossy.webp").binread
      end

      def stored?(blob) = ActiveStorage::Blob.service.exist?(blob.key)

      test "store garde les octets avec leur format et leurs dimensions, sans analyse, rattachés à aucun article" do
        stored = nil
        assert_no_enqueued_jobs(only: ActiveStorage::AnalyzeJob) do
          stored = @store.store(data: @webp, content_type: "image/webp", width: 64, height: 48)
        end
        image = Orm::ArticleImage.find_by!(public_id: stored.public_id)

        assert_equal Port::StoredImage.new(public_id: image.public_id, sgid: image.attachable_sgid, width: 64, height: 48), stored
        assert_equal [ nil, nil, "image/webp", @webp.bytesize, 64, 48 ],
                     [ image.article_id, image.alt, image.content_type, image.byte_size, image.width, image.height ]
        assert_equal [ "image.webp", "image/webp", true ], [ image.file.filename.to_s, image.file.content_type, image.file.metadata[:analyzed] ]
        assert_equal @webp, image.file.download
        assert stored?(image.file.blob)
      end

      test "read rend les octets, le format et l'état de l'article ; nil pour une image inconnue" do
        orphan = @store.store(data: @webp, content_type: "image/webp", width: 64, height: 48)
        draft = create_article_image(article: create_article(status: "draft"), fixture: "photos/photo.png")
        archived = create_article_image(article: create_article(status: "archived"))

        assert_equal Port::ServedImage.new(content_type: "image/webp", data: @webp, article_status: nil), @store.read(public_id: orphan.public_id)
        assert_equal Port::ServedImage.new(content_type: "image/png", data: file_fixture("photos/photo.png").binread, article_status: "draft"),
                     @store.read(public_id: draft.public_id)
        assert_equal [ "image/jpeg", "archived" ], @store.read(public_id: archived.public_id).then { [ it.content_type, it.article_status ] }
        assert_nil @store.read(public_id: "inconnu0000000")
      end

      test "purge_orphans supprime les images jamais rattachées envoyées avant la limite, et leur fichier" do
        limit = 48.hours.ago
        old = create_article_image(created_at: 49.hours.ago)
        recent = create_article_image(created_at: 47.hours.ago)
        attached = create_article_image(article: create_article, created_at: 30.days.ago)
        blob = old.file.blob

        assert_equal 1, perform_enqueued_jobs { @store.purge_orphans(before: limit) }

        assert_equal [ recent, attached ].map(&:id).sort, Orm::ArticleImage.pluck(:id).sort
        assert_not ActiveStorage::Blob.exists?(blob.id)
        assert_not stored?(blob)
        assert_equal 0, @store.purge_orphans(before: limit)
      end

      # Une couverture est rattachée à son article à l'enregistrement ; si une ligne la désignait sans l'être, elle
      # resterait : la clé étrangère refuserait sa suppression, et l'image est encore utile.
      test "purge_orphans ne touche jamais une couverture" do
        cover = create_article_image(created_at: 3.days.ago)
        article = create_article(cover:)
        cover.update_columns(article_id: nil)

        assert_equal 0, @store.purge_orphans(before: 48.hours.ago)
        assert_equal cover, article.reload.cover_image
      end
    end
  end
end
