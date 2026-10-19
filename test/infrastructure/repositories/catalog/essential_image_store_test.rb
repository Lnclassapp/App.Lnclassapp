require "test_helper"

# ADR-0105 §4.7 : une image de fiche est une ligne d'essential_images et son fichier sur le service Active Storage, né
# analysé ; elle se lit avec le slug de sa fiche ; elle se compte par fiche ; une orpheline de plus de 48 h est purgée.
module Repositories
  module Catalog
    class EssentialImageStoreTest < ActiveSupport::TestCase
      include ActiveJob::TestHelper

      Port = Ports::Catalog::EssentialImageStorePort

      setup do
        @store = EssentialImageStore.new
        @webp = file_fixture("photos/photo_lossy.webp").binread
      end

      test "store garde les octets, sans analyse, rattachés à aucune fiche" do
        stored = nil
        assert_no_enqueued_jobs(only: ActiveStorage::AnalyzeJob) do
          stored = @store.store(data: @webp, content_type: "image/webp", width: 64, height: 48)
        end
        image = Orm::EssentialImage.find_by!(public_id: stored.public_id)

        assert_equal Port::StoredImage.new(public_id: image.public_id, sgid: image.attachable_sgid, width: 64, height: 48), stored
        assert_equal [ nil, "image/webp", @webp.bytesize, 64, 48 ], [ image.essential_id, image.content_type, image.byte_size, image.width, image.height ]
        assert_equal [ "image.webp", true ], [ image.file.filename.to_s, image.file.metadata[:analyzed] ]
        assert_equal @webp, image.file.download
      end

      test "find rend le format et la fiche en une requête ; nil pour une image inconnue" do
        orphan = @store.store(data: @webp, content_type: "image/webp", width: 64, height: 48)
        essential = create_essential(status: "draft")
        attached = create_essential_image(essential:, fixture: "photos/photo.png")

        assert_equal Port::ImageState.new(content_type: "image/webp", essential_slug: nil), @store.find(public_id: orphan.public_id)
        assert_queries_count(1) do
          assert_equal Port::ImageState.new(content_type: "image/png", essential_slug: essential.slug), @store.find(public_id: attached.public_id)
        end
        assert_nil @store.find(public_id: "inconnu0000000")
      end

      test "count_for compte les images rattachées à la fiche" do
        essential = create_essential
        2.times { create_essential_image(essential:) }
        create_essential_image

        assert_equal 2, @store.count_for(essential_slug: essential.slug)
        assert_equal 0, @store.count_for(essential_slug: "inconnue")
      end

      test "download rend les octets ; nil pour une image inconnue" do
        orphan = @store.store(data: @webp, content_type: "image/webp", width: 64, height: 48)

        assert_equal @webp, @store.download(public_id: orphan.public_id)
        assert_nil @store.download(public_id: "inconnu0000000")
      end

      test "purge_orphans supprime les images jamais rattachées envoyées avant la limite, et leur fichier" do
        old = create_essential_image(created_at: 49.hours.ago)
        recent = create_essential_image(created_at: 47.hours.ago)
        attached = create_essential_image(essential: create_essential, created_at: 30.days.ago)
        blob = old.file.blob

        assert_equal 1, perform_enqueued_jobs { @store.purge_orphans(before: 48.hours.ago) }

        assert_equal [ recent, attached ].map(&:id).sort, Orm::EssentialImage.pluck(:id).sort
        assert_not ActiveStorage::Blob.exists?(blob.id)
      end

      # Menace n° 11 : une image rattachée entre la lecture des orphelines et la purge garde sa ligne et son fichier.
      test "purge_orphans laisse l'image rattachée entre la lecture des orphelines et la purge" do
        raced = create_essential_image(created_at: 49.hours.ago)
        essential = create_essential
        @store.define_singleton_method(:orphan_ids) { |before:| super(before:).tap { raced.update_columns(essential_id: essential.id) } }

        assert_equal 0, perform_enqueued_jobs { @store.purge_orphans(before: 48.hours.ago) }
        assert_equal essential.id, raced.reload.essential_id
        assert ActiveStorage::Blob.exists?(raced.file.blob.id)
      end

      test "download rend nil quand la ligne du blob existe mais pas son fichier" do
        stored = @store.store(data: @webp, content_type: "image/webp", width: 64, height: 48)
        blob = Orm::EssentialImage.find_by!(public_id: stored.public_id).file.blob
        blob.service.delete(blob.key)

        assert_nil @store.download(public_id: stored.public_id)
      end

      test "une fiche ne part pas avec ses images (RESTRICT, ADR-0036)" do
        essential = create_essential
        create_essential_image(essential:)

        assert_raises(ActiveRecord::StatementInvalid) { Orm::Essential.where(id: essential.id).delete_all }
      end
    end
  end
end
