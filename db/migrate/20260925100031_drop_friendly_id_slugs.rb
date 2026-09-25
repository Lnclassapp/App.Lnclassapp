# ADR-0029 : friendly_id is not kept, slugs are frozen by Orm::HasFrozenSlug.
class DropFriendlyIdSlugs < ActiveRecord::Migration[8.1]
  def change
    drop_table :friendly_id_slugs do |t|
      t.string :slug, null: false
      t.integer :sluggable_id, null: false
      t.string :sluggable_type, limit: 50
      t.string :scope
      t.datetime :created_at
      t.index [ :sluggable_type, :sluggable_id ]
      t.index [ :slug, :sluggable_type ], length: { slug: 140, sluggable_type: 50 }
      t.index [ :slug, :sluggable_type, :scope ], length: { slug: 70, sluggable_type: 50, scope: 70 }, unique: true
    end
  end
end
