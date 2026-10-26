require "test_helper"

module Shared
  module Navigation
    # UDR accueil élève §3.1 and UDR enseignant §3.1, §3.3 (mvp-teacher-student): the band of both homes — the role's colour
    # chosen by role_fill_class, the avatar on the left (opens « Mon compte »), « Besoin d'aide ? » on the right, text in
    # band-ink, both hidden from lg (the top bar already carries them).
    class HomeBandTest < ActionView::TestCase
      helper NavigationHelper, ComponentsHelper

      def user(role, **) = NavigationHelper::ShellUser.new(name: "Awa Koné", role:, **)

      def band(role, **) = render(partial: "shared/navigation/home_band", locals: { role:, user: user(role, **) })

      test "the student's band: brand blue, avatar on the left, help on the right, band-ink text" do
        band(:student)

        assert_select "header.student-band.bg-brand.text-band-ink.min-h-24" do
          assert_select "a[href='#{student_menu_path}'][aria-label=?]", I18n.t("shared.navigation.home_band.account", name: "Awa Koné") do
            assert_select ".size-12.rounded-full.bg-white.text-brand-strong", text: "AK"
          end
          assert_select "a[href='#{help_path}'].text-band-ink", text: I18n.t("shared.navigation.home_band.help")
          assert_select "a svg", 1
        end
        assert_select ".bg-teacher", 0
      end

      test "the teacher's band: teacher yellow, taller, same content" do
        band(:teacher)

        assert_select "header.teacher-band.bg-teacher.text-band-ink.min-h-33" do
          assert_select "a[href='#{teacher_menu_path}']"
          assert_select "a[href='#{help_path}']", text: "Besoin d'aide ?"
        end
        assert_select ".bg-brand", 0
      end

      test "the avatar and the help leave the band from lg, the top bar carries them" do
        band(:student)

        assert_select "header > a.lg\\:hidden", 2
      end

      test "a photo replaces the initials" do
        band(:teacher, avatar_url: "/accounts/abc/photo")

        assert_select "a[href='#{teacher_menu_path}'] img[src='/accounts/abc/photo'].size-12.rounded-full.object-cover"
        assert_select "a[href='#{teacher_menu_path}'] .bg-white", 0
      end

      test "another role has no band" do
        error = assert_raises(ActionView::Template::Error) { band(:team) }

        assert_instance_of KeyError, error.cause
      end
    end
  end
end
