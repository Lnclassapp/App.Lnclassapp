require "test_helper"

# UDR-0071 §3.7 « Enseignants » (direction) and « Toutes » (team), ADR-0078 §4.2: the announcements in progress a
# moderator may withdraw, each as its card, with its school and its dates, and « Retirer » behind a confirmation; the
# team filters them by school. A teacher and a student receive 403, a visitor is sent to « Se connecter ».
module Communication
  class ModerationsControllerTest < ActionDispatch::IntegrationTest
    NOW = Time.zone.local(2026, 10, 4, 12)
    FRAME = "turbo-frame#moderated_announcements".freeze

    setup do
      travel_to NOW
      @lauriers = create_school(name: "Collège Les Lauriers", sigle: "CLL")
      @bouake = create_school(name: "Lycée de Bouaké", sigle: "LYB")
      @b3 = create_classroom(school: @lauriers, name: "3ème B")
      @terminale = create_classroom(school: @bouake, name: "Terminale D")
      @kouassi = create_teacher(school: @lauriers, material: create_material(name: "SVT"), classrooms: [ @b3 ], gender: "male",
                                last_name: "Kouassi")
      @kamate = create_school_admin(school: @lauriers, gender: "female", last_name: "Kamaté")
      @fatou = create_team_member(first_name: "Fatou")
    end

    def tl(key, **) = I18n.t("communication.moderations.index.#{key}", **)
    def tm(key, **) = I18n.t("communication.moderations.moderated_message.#{key}", **)
    def titles = css_select("#{FRAME} li article h3").map(&:text)

    def fiches(**)
      create_message(author: @kouassi, title: "Nouvelles fiches", audience: "classrooms", classrooms: [ @b3 ],
                     published_at: Time.zone.local(2026, 10, 3, 8), ends_at: Time.zone.local(2026, 11, 2), **)
    end

    def bouake
      create_message(author: create_teacher(school: @bouake, classrooms: [ @terminale ]), title: "Fiches de Bouaké",
                     audience: "classrooms", classrooms: [ @terminale ], published_at: 3.hours.ago)
    end

    def rentree = create_message(author: create_team_member(second_factor: false), title: "Rentrée numérique", audience: "all")

    test "AN-17 — « Enseignants » of the direction: the announcements of the teachers of its school, nothing else" do
      fiche = fiches
      create_message(author: @kamate, title: "Devoirs communs", school: @lauriers)
      create_message(author: create_school_admin(school: @lauriers, last_name: "Diallo"), title: "Réunion", school: @lauriers)
      rentree
      bouake
      sign_in_as @kamate

      get moderated_announcements_path

      assert_response :success
      assert_select "title", "#{tl('page_title.school_admin')} · Direction · Lnclass"
      assert_select "h1", tl("title")
      assert_select "nav#announcement-tabs a[aria-current=page][href=?]", moderated_announcements_path, text: "Enseignants"
      assert_select "form#moderation-filter", 0
      assert_equal [ "Nouvelles fiches" ], titles
      assert_select "#{FRAME} ul#moderated_announcements_list.grid.gap-3 > li#moderated_announcement_#{fiche.public_id}" do
        assert_select "article#announcement_#{fiche.public_id} p span.truncate", "M. Kouassi · SVT"
        assert_select "article form", 0
        assert_select "article + div.flex.items-center.justify-between.gap-3.pt-2 > p.text-sm.text-mute",
                      "Collège Les Lauriers · Publiée le 3 oct. · jusqu'au 1ᵉʳ nov."
      end
    end

    test "AN-16, AN-17 — each line has « Retirer », confirmed in a dialog that posts the withdrawal in Turbo Stream" do
      fiche = fiches
      sign_in_as @kamate

      get moderated_announcements_path

      assert_select "#moderated_announcement_#{fiche.public_id}" do
        assert_select "button[data-action='modal#open'][aria-controls='withdraw-#{fiche.public_id}']", text: tm("withdraw") do
          assert_select "svg"
        end
        assert_select "dialog#withdraw-#{fiche.public_id}" do
          assert_select "h2", tm("withdraw_title")
          assert_select "p", tm("withdraw_text")
          assert_select "button[data-action='modal#close']", tm("cancel")
          assert_select "form[action=?][method=post] button[type=submit][data-turbo-stream=true].bg-error",
                        announcement_withdrawal_path(fiche.public_id), text: tm("withdraw")
        end
      end
      assert_equal "Retirer cette annonce ?", tm("withdraw_title")
      assert_equal "Elle disparaîtra pour tous ses destinataires. Son auteur la verra « Retirée » et ne pourra pas la republier.",
                   tm("withdraw_text")
    end

    test "a scheduled announcement shows its publication date and time" do
      fiches(status: "scheduled", published_at: Time.zone.local(2026, 10, 5, 10))
      sign_in_as @kamate

      get moderated_announcements_path

      assert_select "#{FRAME} li p.text-mute", "Collège Les Lauriers · Programmée le 5 oct. à 10:00"
    end

    test "AN-16 — « Toutes » of the team: every announcement of another author, a national one « Tout le pays », and the filter" do
      fiches
      rentree
      bouake
      create_message(author: @fatou, title: "Les miennes", audience: "all")
      sign_in_as @fatou

      get moderated_announcements_path

      assert_response :success
      assert_select "title", "#{tl('page_title.team')} · Équipe · Lnclass"
      assert_select "nav#announcement-tabs a[aria-current=page][href=?]", moderated_announcements_path, text: "Toutes"
      assert_equal [ "Rentrée numérique", "Fiches de Bouaké", "Nouvelles fiches" ], titles
      assert_select "#{FRAME} li p.text-mute", text: /\ATout le pays · Publiée le 4 oct\./
      assert_select "form#moderation-filter[method=get][action=?][role=search][data-controller=search]" \
                    "[data-turbo-frame=moderated_announcements]", moderated_announcements_path do
        assert_select "label[for=q]", text: /#{tl('filter.school')}/
        assert_select "input#q[type=search][name=q][data-action~='search#queue'][aria-describedby=q_hint]"
        assert_select "#q_hint", tl("filter.hint")
        assert_select "button[type=submit][data-search-target=button]", tl("filter.submit")
        assert_select "template[data-search-target=error]"
      end
      assert_equal [ "Établissement", "Nom ou sigle" ], [ tl("filter.school"), tl("filter.hint") ]
    end

    test "the team filters by the name or the sigle of the school; the field keeps what was typed" do
      fiches
      rentree
      bouake
      sign_in_as @fatou

      get moderated_announcements_path(q: "lyb"), headers: { "Turbo-Frame" => "moderated_announcements" }

      assert_response :success
      assert_equal [ "Fiches de Bouaké" ], titles
      assert_select "input#q[value=lyb]"
    end

    test "the frame shows a skeleton while a filter or a page is loading" do
      fiches
      sign_in_as @fatou

      get moderated_announcements_path

      assert_select "#{FRAME}.group[data-turbo-action=advance]" do
        assert_select "div.hidden[class~='group-aria-busy:block'] [role=status][aria-busy=true]"
        assert_select "div[class~='group-aria-busy:hidden'] ul#moderated_announcements_list"
      end
    end

    test "empty: the direction, the team, and the team's filter without result have their own text" do
      sign_in_as @kamate
      get moderated_announcements_path
      assert_select "#{FRAME} p.font-display", "Vos enseignants n'ont aucune annonce en cours."
      assert_select "#{FRAME} svg", minimum: 1
      sign_out

      sign_in_as @fatou
      get moderated_announcements_path
      assert_select "#{FRAME} p.font-display", "Aucune annonce en cours."
      rentree
      get moderated_announcements_path(q: "Abidjan")
      assert_select "#{FRAME} p.font-display", "Aucune annonce pour cet établissement."
      assert_select "#{FRAME} ul", 0
    end

    test "the direction's search parameter is ignored: its list and its empty state stay its own" do
      sign_in_as @kamate

      get moderated_announcements_path(q: "Abidjan")

      assert_select "#{FRAME} p.font-display", "Vos enseignants n'ont aucune annonce en cours."
    end

    test "twenty per page, newest first, with the pagination" do
      21.times { |index| create_message(author: @kouassi, title: "Annonce #{index}", audience: "classrooms", classrooms: [ @b3 ], published_at: (index + 1).minutes.ago) }
      sign_in_as @kamate

      get moderated_announcements_path

      assert_equal 20, titles.size
      assert_equal "Annonce 0", titles.first
      assert_select "#{FRAME} nav p", "Page 1 sur 2"
      get moderated_announcements_path(page: 2)
      assert_equal [ "Annonce 20" ], titles
    end

    test "a teacher and a student receive 403, a visitor is sent to sign in" do
      [ @kouassi, create_student(classroom: @b3) ].each do |user|
        sign_in_as user
        get moderated_announcements_path
        assert_response :forbidden
        sign_out
      end

      get moderated_announcements_path
      assert_redirected_to new_session_path
    end
  end
end
