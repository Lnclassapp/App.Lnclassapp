require "test_helper"

module Shared
  module Navigation
    # carte-profil-eleve (UDR-0132 §3.1, amendée) : la barre latérale de l'élève (lg et plus) ouvre, comme celle de l'enseignant
    # (UDR enseignant §3.14), sur la carte de profil — avatar, nom complet, classe et établissement — puis la navigation.
    class SidebarTest < ActionView::TestCase
      helper NavigationHelper, ComponentsHelper

      CARD = "aside > div.rounded-card.border-line.bg-white.shadow-card:first-child".freeze

      def student(**attributes)
        NavigationHelper::ShellUser.new(name: "Awa Koné", role: :student, public_id: "stu-1", **attributes)
      end

      def placed(**attributes)
        about = Queries::Identity::ShellUserQuery::About.new(gender: "female", classroom: "3ème B", school: "Lycée Moderne de Cocody", sigle: "LMC")
        student(about:, **attributes)
      end

      test "CA-1: avatar, full name, then « classe · sigle » as the teacher's « matière · sigle », then the navigation card below" do
        render partial: "shared/navigation/sidebar", locals: { user: placed }

        assert_select "aside.hidden.lg\\:block" do
          assert_select CARD do
            assert_select "[role=img][aria-label='Awa Koné']", text: "AK"
            assert_select "p.truncate.font-medium", text: "Awa Koné"
            assert_select "p.line-clamp-2.text-xs.text-mute", text: "3ème B · LMC"
            assert_select "a", 0 # the card is not a link: « Mon compte » opens from the header's avatar
          end
          assert_select "#{CARD} + nav.mt-4[aria-label='#{t('shared.navigation.sidebar.label')}'] a", 3
          assert_select "nav#sidebar_secondary", 0
        end
      end

      test "CA-2: a student without a classroom reads « Pas encore de classe », never an empty line" do
        render partial: "shared/navigation/sidebar", locals: { user: student }

        assert_select "#{CARD} p.text-mute", text: "Pas encore de classe"
      end

      test "CA-3: a long name stays on one truncated line, inside a shrinkable column" do
        name = "Marie-Christelle Adjoua Kouassi-N'Guessan de Bingerville"
        render partial: "shared/navigation/sidebar", locals: { user: placed(name:) }

        assert_select "#{CARD} div.min-w-0 > p.truncate", text: name
      end

      test "CA-4: with a photo, the photo; without, the initials coloured from the public id, as in the header" do
        render partial: "shared/navigation/sidebar", locals: { user: student(avatar_url: "/photo.jpg") }
        assert_select "#{CARD} img.ui-avatar[alt='Awa Koné'][src='/photo.jpg']"

        tone = ComponentsHelper::AVATAR_TONES.values["stu-1".sum % ComponentsHelper::AVATAR_TONES.size]
        render partial: "shared/navigation/sidebar", locals: { user: student }
        assert_select "#{CARD} [role=img][class*='#{tone}']", text: "AK"
      end

      test "the other adults keep their card and their detail; no « Pas encore de classe » outside the student" do
        render partial: "shared/navigation/sidebar", locals: { user: NavigationHelper::ShellUser.new(name: "Ali Traoré", role: :team) }

        assert_select "#{CARD} p.font-medium", text: "Ali Traoré"
        assert_select "#{CARD} p.text-mute", 0
        assert_select "nav#sidebar_secondary", 1
      end
    end
  end
end
