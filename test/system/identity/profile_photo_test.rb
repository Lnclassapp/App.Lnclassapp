require "application_system_test_case"

# PH-01 to PH-04, PH-07, ADR-0060, UDR-0047: from « Mon profil », a student adds a photo from a file, sees it cropped
# before sending, then in the account menu; a heavy image is lightened by the browser; a PDF is refused by the server;
# the photo is removed and the initials come back. The same journey holds on a 390 px phone.
class Identity::ProfilePhotoTest < ApplicationSystemTestCase
  setup do
    @student = create_student(classroom: create_classroom, first_name: "Aya", last_name: "Koné")
  end

  def stored = Orm::User.find(@student.id).photo
  def stored_facts = Entities::Identity::ImageHeader.read(stored.download)

  def open_photo_modal
    visit profile_path
    within("#profile_information") { click_on(stored.attached? ? "Changer ma photo" : "Ajouter une photo") }
    assert_selector "turbo-frame#modal dialog[open]", text: "Ma photo"
  end

  # A photo served by its authenticated route has really loaded: the browser decoded it (retried while it loads).
  def assert_photo_loaded(selector)
    assert_selector selector
    page.document.synchronize do
      loaded = page.evaluate_script("(img => img.complete && img.naturalWidth > 0)(document.querySelector(#{selector.to_json}))")
      raise Capybara::ExpectationNotMet, "#{selector} n'a pas chargé" unless loaded
    end
  end

  def screenshot(name)
    return if ENV["PHOTO_SCREENSHOTS"].blank?

    sleep 0.4 # the end of the menu and toast transitions
    page.save_screenshot(File.join(ENV["PHOTO_SCREENSHOTS"], "#{name}.png"))
  end

  # 700 × 700 px of noise: a PNG of more than 1 MB, which the server alone would refuse.
  def heavy_png
    row = ->(_) { "\0" + Random.bytes(700 * 3) }
    chunk = ->(type, data) { [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N") }
    png = "\x89PNG\r\n\x1A\n".b + chunk.("IHDR", [ 700, 700, 8, 2, 0, 0, 0 ].pack("NNCCCCC")) +
          chunk.("IDAT", Zlib::Deflate.deflate(Array.new(700, &row).join, Zlib::NO_COMPRESSION)) + chunk.("IEND", "")
    Rails.root.join("tmp/heavy-#{SecureRandom.hex(4)}.png").tap { File.binwrite(it, png) }
  end

  test "the student adds a photo, sees it cropped before sending, then in the account menu; then removes it" do
    sign_in_as @student
    open_photo_modal
    assert_selector "[data-identity--photo-picker-target=current] [role=img]", text: "AK"

    assert_no_page_reload do
      attach_file "profile_photo[photo]", file_fixture("photos/portrait.jpg")
      assert_selector "img[data-identity--photo-picker-target=preview][src^='blob:']"
      assert_no_selector "[data-identity--photo-picker-target=current]"
      screenshot("1-apercu")
      within("turbo-frame#modal dialog[open]") { click_on "Enregistrer" }

      assert_toast "Votre photo est enregistrée."
      assert_no_selector "turbo-frame#modal dialog[open]"
      assert_photo_loaded "#profile_information img[alt='Aya Koné']"
      assert_photo_loaded "header button[aria-controls=account-menu] img[alt='Aya Koné']"
    end
    assert_equal Entities::Identity::ImageHeader::Facts.new(format: :webp, width: 480, height: 480, metadata: false), stored_facts
    assert Orm::AuditEvent.exists?(action: "profile.photo_changed", actor_id: @student.id)
    screenshot("2-profil-avec-photo")
    find("button[aria-controls='account-menu']").click
    screenshot("3-menu-du-compte")
    find("button[aria-controls='account-menu']").click

    open_photo_modal
    assert_no_page_reload do
      within("turbo-frame#modal dialog[open]") { click_on "Retirer ma photo" }

      assert_toast "Votre photo est retirée."
      within("#profile_information") { assert_selector "[role=img][aria-label='Aya Koné']", text: "AK" }
      assert_selector "header button[aria-controls=account-menu] [role=img]", text: "AK"
    end
    assert_not stored.attached?
  end

  test "an image of more than 1 MB is lightened by the browser: square, 512 px, well under 1 MB" do
    path = heavy_png
    assert_operator File.size(path), :>, Entities::Identity::ProfilePhoto::MAX_BYTES
    sign_in_as @student
    open_photo_modal

    attach_file "profile_photo[photo]", path
    assert_selector "img[data-identity--photo-picker-target=preview][src^='blob:']"
    within("turbo-frame#modal dialog[open]") { click_on "Enregistrer" }

    assert_toast "Votre photo est enregistrée."
    assert_equal [ 512, 512, false ], stored_facts.then { [ it.width, it.height, it.metadata ] }
    assert_operator stored.byte_size, :<, Entities::Identity::ProfilePhoto::MAX_BYTES
  ensure
    FileUtils.rm_f(path)
  end

  test "a PDF cannot be cropped: it reaches the server, which refuses it in the modal; nothing is stored" do
    sign_in_as @student
    open_photo_modal

    attach_file "profile_photo[photo]", file_fixture("photos/document.pdf")
    within("turbo-frame#modal dialog[open]") { click_on "Enregistrer" }

    within "turbo-frame#modal dialog[open]" do
      assert_selector "#profile_photo_photo_error", text: "Choisissez une photo JPEG, PNG ou WebP."
    end
    assert_not stored.attached?
  end

  test "on a 390 px phone, the modal fits the screen and the photo is added" do
    sign_in_as @student
    with_mobile_viewport do
      open_photo_modal
      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      attach_file "profile_photo[photo]", file_fixture("photos/portrait.jpg")
      assert_selector "img[data-identity--photo-picker-target=preview][src^='blob:']"
      screenshot("4-mobile-apercu")
      within("turbo-frame#modal dialog[open]") { click_on "Enregistrer" }

      assert_toast "Votre photo est enregistrée."
      assert_photo_loaded "#profile_information img[alt='Aya Koné']"
      assert_photo_loaded "header button[aria-controls=account-menu] img[alt='Aya Koné']"
      assert_equal 0, page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
      find("#toasts button[data-action='toast#dismiss']").click
      assert_no_selector "#toasts [data-controller=toast]"
      screenshot("5-mobile-profil")
    end
  end
end
