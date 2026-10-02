require "test_helper"

# ADR-0073 §4.4 : une image envoyée puis jamais enregistrée (modale fermée) est supprimée après 48 h, son fichier purgé
# après validation ; une image citée par un article, ou sa couverture, ne l'est jamais.
class Communication::PurgeOrphanArticleImagesJobTest < ActiveJob::TestCase
  test "une image non rattachée est gardée à 47 h, supprimée à 49 h, son fichier purgé ; une image rattachée, jamais" do
    stale = create_article_image(created_at: 49.hours.ago)
    recent = create_article_image(created_at: 47.hours.ago)
    cited = create_article_image(created_at: 49.hours.ago)
    cover = create_article_image(created_at: 49.hours.ago)
    create_article(status: "draft", excerpt: nil, cover:, body: article_body_with(cited))
    blob = stale.file.blob

    Communication::PurgeOrphanArticleImagesJob.perform_now

    assert_not Orm::ArticleImage.exists?(stale.id)
    assert_equal [ recent, cited, cover ].map(&:id).sort, Orm::ArticleImage.ids.sort
    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [ blob ])
    assert_enqueued_jobs 1, only: ActiveStorage::PurgeJob
  end

  test "une couverture détachée de tout texte n'est jamais purgée" do
    cover = create_article_image(created_at: 3.days.ago)
    create_article(cover:)
    cover.update_columns(article_id: nil)

    Communication::PurgeOrphanArticleImagesJob.perform_now

    assert Orm::ArticleImage.exists?(cover.id)
  end
end
