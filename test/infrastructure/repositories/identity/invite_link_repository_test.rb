require "test_helper"

module Repositories
  module Identity
    # ADR-0082 §4.1: the token of an invite link /i/<token> is a colleague's referral token, or the direction or team
    # token of a school. The repository says who invites and to which school; the caller judges with valid?.
    class InviteLinkRepositoryTest < ActiveSupport::TestCase
      InviteLink = Ports::Identity::InviteLinkRepositoryPort::InviteLink

      setup { @repository = InviteLinkRepository.new }

      def referral_token_of(teacher) = Orm::TeacherProfile.find_by!(user: teacher).referral_token

      test "a colleague's referral token gives his primary school and the colleague channel" do
        school = create_school
        colleague = create_teacher(school:)

        link = @repository.resolve(token: referral_token_of(colleague))

        assert_equal InviteLink.new(school_id: school.id, school_active: true, channel: "colleague", referrer_id: colleague.id), link
        assert link.valid?
      end

      test "the direction and team tokens of a school give that school and their channel, without referrer" do
        school = create_school.reload

        assert_equal InviteLink.new(school_id: school.id, school_active: true, channel: "direction", referrer_id: nil),
                     @repository.resolve(token: school.direction_invite_token)
        assert_equal InviteLink.new(school_id: school.id, school_active: true, channel: "team", referrer_id: nil),
                     @repository.resolve(token: school.team_invite_token)
      end

      test "an unknown token is nil" do
        assert_nil @repository.resolve(token: "ffffffffffff")
      end

      test "a colleague without primary school gives a link without school, not valid" do
        pending = create_teacher(school: nil)

        link = @repository.resolve(token: referral_token_of(pending))

        assert_equal InviteLink.new(school_id: nil, school_active: false, channel: "colleague", referrer_id: pending.id), link
        assert_not link.valid?
      end

      # Memo, cas limites : le lien d'un collègue supprimé est invalide. Anonymisé, il garde parfois son rattachement.
      test "an anonymized colleague gives a link without school, not valid, even when still attached to an active school" do
        colleague = create_teacher(school: create_school)
        Orm::User.where(id: colleague.id).update_all(anonymized_at: Time.current)

        link = @repository.resolve(token: referral_token_of(colleague))

        assert_equal InviteLink.new(school_id: nil, school_active: false, channel: "colleague", referrer_id: colleague.id), link
        assert_not link.valid?
      end

      test "a school that is not active gives a link that is not valid, whoever invites" do
        closed = create_school(status: "inactive").reload
        colleague = create_teacher(school: closed)

        [ referral_token_of(colleague), closed.direction_invite_token, closed.team_invite_token ].each do |token|
          link = @repository.resolve(token:)
          assert_equal [ closed.id, false ], [ link.school_id, link.school_active ], token
          assert_not link.valid?, token
        end
      end

      test "a token both a colleague's and a school's resolves to the colleague first, then the direction, then the team" do
        colleague = create_teacher
        token = referral_token_of(colleague)
        direction_school = create_school
        team_school = create_school
        direction_school.update_column(:direction_invite_token, token)
        team_school.update_column(:team_invite_token, token)

        assert_equal "colleague", @repository.resolve(token:).channel
        Orm::TeacherProfile.where(user: colleague).update_all(referral_token: "aaaaaaaaaaaa")
        assert_equal [ "direction", direction_school.id ], @repository.resolve(token:).then { [ it.channel, it.school_id ] }
        direction_school.update_column(:direction_invite_token, "bbbbbbbbbbbb")
        assert_equal [ "team", team_school.id ], @repository.resolve(token:).then { [ it.channel, it.school_id ] }
      end
    end
  end
end
