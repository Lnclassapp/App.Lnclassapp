require "test_helper"

# ADR-0060: the version of a photo, carried by its address, changes with the file; the browser's private cache can
# then keep an image as long as its address lives.
module Queries
  module Identity
    class PhotoVersionsTest < ActiveSupport::TestCase
      test "one version per account with a photo, URL-safe, that changes with the file" do
        with_photo = attach_photo(create_student)
        without = create_student

        versions = PhotoVersions.for(user_ids: [ with_photo.id, without.id ])

        assert_equal [ with_photo.id ], versions.keys
        assert_match(/\A[A-Za-z0-9_-]{22}\z/, versions[with_photo.id])
        attach_photo(with_photo, "photo.png")
        assert_not_equal versions[with_photo.id], PhotoVersions.for(user_ids: [ with_photo.id ])[with_photo.id]
      end

      test "of turns a blob checksum into the version, and nil into nil" do
        assert_equal "1B2M2Y8AsgTpgAmY7PhCfg", PhotoVersions.of("1B2M2Y8AsgTpgAmY7PhCfg==")
        assert_equal "a-b_", PhotoVersions.of("a+b/")
        assert_nil PhotoVersions.of(nil)
      end
    end
  end
end
