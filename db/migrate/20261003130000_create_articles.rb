# ADR-0074 §4.1 : the public blog in `communication`. An article has a public_id (team addresses) and a frozen slug
# (public address), the content life cycle of ADR-0035 and a reads counter written by one UPDATE (not indexed, so the
# update stays HOT). Its images are rows of article_images, checked files without metadata (ADR-0060), NULL article
# between upload and the first save that cites them. Nothing is ever deleted through a foreign key (RESTRICT); the two
# crossed foreign keys are added once both tables exist.
class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.string :slug, limit: 140, null: false, index: { unique: true }
      t.string :title, limit: 120, null: false
      t.string :excerpt, limit: 200
      t.bigint :cover_image_id
      t.string :cover_alt, limit: 150
      t.string :signature, null: false, default: "team"
      t.string :status, null: false, default: "draft"
      t.datetime :published_at
      t.datetime :archived_at
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.integer :reads_count, null: false, default: 0
      t.timestamps
      t.check_constraint "char_length(btrim(title)) >= 1", name: "articles_title_present"
      t.check_constraint "status IN ('draft','published','archived')", name: "articles_status_values"
      t.check_constraint "signature IN ('team','author')", name: "articles_signature_values"
      t.check_constraint "status = 'draft' OR (published_at IS NOT NULL AND btrim(excerpt) <> '')", name: "articles_published_complete"
      t.check_constraint "(status = 'archived') = (archived_at IS NOT NULL)", name: "articles_archived_at"
      t.check_constraint "reads_count >= 0", name: "articles_reads_count_positive"
      t.index %i[published_at id], order: { published_at: :desc, id: :desc }, where: "status = 'published'",
                                   name: "index_articles_published"
    end

    create_table :article_images do |t|
      t.string :public_id, limit: 14, null: false, index: { unique: true }
      t.references :article
      t.string :alt, limit: 150
      t.string :content_type, null: false
      t.integer :byte_size, null: false
      t.integer :width, null: false
      t.integer :height, null: false
      t.timestamps
      t.check_constraint "content_type IN ('image/jpeg','image/png','image/webp')", name: "article_images_content_type_values"
      t.check_constraint "byte_size BETWEEN 1 AND 1048576", name: "article_images_byte_size"
      t.check_constraint "width BETWEEN 1 AND 1600 AND height BETWEEN 1 AND 1600", name: "article_images_sides"
    end

    add_foreign_key :article_images, :articles, on_delete: :restrict
    add_foreign_key :articles, :article_images, column: :cover_image_id, on_delete: :restrict
  end
end
