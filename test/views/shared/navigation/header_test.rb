require "test_helper"

module Shared
  module Navigation
    # CA-G12 (UDR enseignant §3.14, lot P0 de mvp-teacher-student): the teacher's top bar at the registration — the same bar from
    # lg (yellow strip, logo, « Lnclass », « Besoin d'aide ? »), without the avatar, and no bar at all below lg (the page has its
    # own header on a phone). The bar of a signed-in teacher is covered by test/integration/identity/teacher_header_test.rb.
    class HeaderTest < ActionView::TestCase
      helper NavigationHelper, ComponentsHelper, BrandHelper

      test "at the registration: strip, logo and help, no avatar, hidden below lg" do
        render partial: "shared/navigation/header", locals: { user: nil }

        assert_select "header.max-lg\\:hidden" do
          assert_select "div.bg-teacher.h-1.max-lg\\:hidden[aria-hidden=true]", 1
          assert_select "a.lg\\:flex[href='/']" do
            assert_select "img[src*='logo']", 1
            assert_select "span", "Lnclass"
          end
          assert_select "a[aria-controls=help-sheet-bar]", 1
          assert_select "[aria-controls=account_panel], dialog#account_panel", 0
        end
      end
    end
  end
end
