# Stockage de photos en mémoire pour les tests du domaine (ADR-0060) : { user_id => StoredPhoto }.
class FakeProfilePhotoStore
  include Ports::Identity::ProfilePhotoStorePort

  attr_reader :photos, :writes

  def initialize(photos = {})
    @photos = photos
    @writes = []
  end

  def attach(user_id:, data:, content_type:)
    @writes << [ :attach, user_id ]
    @photos[user_id] = StoredPhoto.new(content_type:, data:)
    true
  end

  def attached?(user_id:) = @photos.key?(user_id)

  def remove(user_id:)
    @writes << [ :remove, user_id ]
    !@photos.delete(user_id).nil?
  end

  def read(user_id:) = @photos[user_id]
end
