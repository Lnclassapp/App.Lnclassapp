# Photo de profil attachée comme l'application l'attache (ADR-0060) : Repositories::Identity::ProfilePhotoStore.
module Factories
  module Photo
    ActiveSupport::TestCase.include(self)

    CONTENT_TYPES = { ".jpg" => "image/jpeg", ".png" => "image/png", ".webp" => "image/webp" }.freeze

    def attach_photo(user, name = "photo.jpg")
      Repositories::Identity::ProfilePhotoStore.new.attach(user_id: user.id, data: file_fixture("photos/#{name}").binread,
                                                           content_type: CONTENT_TYPES.fetch(File.extname(name)))
      user.reload
    end
  end
end
