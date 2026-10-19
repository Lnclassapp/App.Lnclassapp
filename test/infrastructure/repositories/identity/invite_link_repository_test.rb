require "test_helper"

module Repositories
  module Identity
    # ADR-0083 §4.1, ADR-0094 §11 (MET-8): the token of an invite link /i/<token> is a colleague's link for one of his
    # schools (teacher_schools.invite_token), his sponsor link without school (teacher_profiles.referral_token), or the
    # direction or team token of a school. The repository says who invites and to which school; the caller judges with valid?.
    class InviteLinkRepositoryTest < ActiveSupport::TestCase
      InviteLink = Ports::Identity::InviteLinkRepositoryPort::InviteLink

      setup { @repository = InviteLinkRepository.new }

      def school_token_of(teacher, school) = Orm::TeacherSchool.find_by!(teacher:, school:).invite_token
      def sponsor_token_of(teacher) = Orm::TeacherProfile.find_by!(user: teacher).referral_token

      test "ME-26: a colleague's link for a school gives that school, primary or not, and the colleague channel" do
        a, b = create_school, create_school
        colleague = create_teacher(school: a)
        add_teacher_school(colleague, b)

        [ a, b ].each do |school|
          link = @repository.resolve(token: school_token_of(colleague, school))

          assert_equal InviteLink.new(school_id: school.id, school_active: true, channel: "colleague", referrer_id: colleague.id), link
          assert link.valid?
        end
      end

      test "ME-27: a colleague's sponsor link has no school, names him, and is valid" do
        colleague = create_teacher

        link = @repository.resolve(token: sponsor_token_of(colleague))

        assert_equal InviteLink.new(school_id: nil, school_active: false, channel: "colleague", referrer_id: colleague.id, sponsor: true), link
        assert link.valid?
      end

      test "the direction and team tokens of a school give that school and their channel, without referrer" do
        school = create_school.reload

        assert_equal InviteLink.new(school_id: school.id, school_active: true, channel: "direction", referrer_id: nil),
                     @repository.resolve(token: school.direction_invite_token)
        assert_equal InviteLink.new(school_id: school.id, school_active: true, channel: "team", referrer_id: nil),
                     @repository.resolve(token: school.team_invite_token)
      end

      test "an unknown token is nil; the link of a school the colleague has left is unknown" do
        a, b = create_school, create_school
        colleague = create_teacher(school: a)
        token = add_teacher_school(colleague, b).invite_token
        Orm::TeacherSchool.where(teacher: colleague, school: b).delete_all

        assert_nil @repository.resolve(token: "ffffffffffff")
        assert_nil @repository.resolve(token:)
      end

      # Memo, cas limites : le lien d'un collègue supprimé est invalide. Anonymisé, il garde parfois son rattachement.
      test "an anonymized colleague: his school link and his sponsor link are not valid" do
        school = create_school
        colleague = create_teacher(school:)
        Orm::User.where(id: colleague.id).update_all(anonymized_at: Time.current)

        school_link = @repository.resolve(token: school_token_of(colleague, school))
        sponsor_link = @repository.resolve(token: sponsor_token_of(colleague))

        assert_equal InviteLink.new(school_id: nil, school_active: false, channel: "colleague", referrer_id: colleague.id), school_link
        assert_equal InviteLink.new(school_id: nil, school_active: false, channel: "colleague", referrer_id: nil, sponsor: true), sponsor_link
        assert_not school_link.valid?
        assert_not sponsor_link.valid?
      end

      test "a school that is not active gives a link that is not valid, whoever invites" do
        closed = create_school(status: "inactive").reload
        colleague = create_teacher(school: closed)

        [ school_token_of(colleague, closed), closed.direction_invite_token, closed.team_invite_token ].each do |token|
          link = @repository.resolve(token:)
          assert_equal [ closed.id, false ], [ link.school_id, link.school_active ], token
          assert_not link.valid?, token
        end
      end

      test "a token shared by several tables resolves to the colleague's school link, his sponsor link, the direction, then the team" do
        colleague = create_teacher
        token = Orm::TeacherSchool.find_by!(teacher: colleague).invite_token
        Orm::TeacherProfile.where(user: colleague).update_all(referral_token: token)
        direction_school = create_school
        team_school = create_school
        direction_school.update_column(:direction_invite_token, token)
        team_school.update_column(:team_invite_token, token)

        assert_equal [ "colleague", false ], @repository.resolve(token:).then { [ it.channel, it.sponsor ] }
        Orm::TeacherSchool.where(teacher: colleague).update_all(invite_token: "cccccccccccc")
        assert_equal [ "colleague", true ], @repository.resolve(token:).then { [ it.channel, it.sponsor ] }
        Orm::TeacherProfile.where(user: colleague).update_all(referral_token: "aaaaaaaaaaaa")
        assert_equal [ "direction", direction_school.id ], @repository.resolve(token:).then { [ it.channel, it.school_id ] }
        direction_school.update_column(:direction_invite_token, "bbbbbbbbbbbb")
        assert_equal [ "team", team_school.id ], @repository.resolve(token:).then { [ it.channel, it.school_id ] }
      end
    end
  end
end
