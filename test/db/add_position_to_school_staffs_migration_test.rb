require "test_helper"
require Rails.root.join("db/migrate/20261016161500_add_position_to_school_staffs").to_s

# ADR-0092 §4.2 (réponse DIR-4 du porteur) : aucune direction n'est inscrite en production. S'il en existait, la migration ne
# l'échouerait pas : chaque ligne recevrait « deputy » (rang gestion, aucun geste perdu, aucun chef inventé), et chaque
# invitation de direction en attente aussi. Chaque test tourne dans la transaction annulée du test.
class AddPositionToSchoolStaffsMigrationTest < ActiveSupport::TestCase
  def migrate(direction)
    changing_schema do
      ActiveRecord::Migration.suppress_messages { AddPositionToSchoolStaffs.new.migrate(direction) }
    end
    [ Orm::SchoolStaff, Orm::Invitation ].each(&:reset_column_information)
  end

  teardown { [ Orm::SchoolStaff, Orm::Invitation ].each(&:reset_column_information) }

  test "existing directions and pending direction invitations get deputy; educator and secretary are kept" do
    heads = Array.new(2) { create_school_admin(school: create_school, position: "head") }
    invited = { "0700000011" => "head", "0700000012" => "secretary" }.to_h do |contact, position|
      [ create_invitation(kind: "school_staff", contact:, position:).id, position ]
    end
    team = create_invitation(kind: "team")

    migrate(:down)
    assert_not_includes Orm::SchoolStaff.column_names, "position"
    migrate(:up)

    assert_equal %w[deputy deputy], Orm::SchoolStaff.where(user_id: heads.map(&:id)).pluck(:position)
    assert_equal({ invited.keys.first => "deputy", invited.keys.last => "secretary" },
                 Orm::Invitation.where(id: invited.keys).pluck(:id, :position).to_h)
    assert_nil team.reload.position
  end

  # Le down rend les anciennes valeurs : head et deputy n'existaient pas, ils redeviennent NULL ; educator et secretary restent ;
  # « principal » est de nouveau accepté, et une invitation de direction sans fonction passe (la contrainte « staff_has_position »
  # n'existe plus).
  test "down: head and deputy invitations lose their position, principal is accepted again, a direction invitation may have none" do
    invited = { "0700000021" => "head", "0700000022" => "deputy", "0700000023" => "educator", "0700000024" => "secretary" }
              .to_h { |contact, position| [ create_invitation(kind: "school_staff", contact:, position:).id, position ] }

    migrate(:down)

    assert_equal [ nil, nil, "educator", "secretary" ], Orm::Invitation.where(id: invited.keys).order(:id).pluck(:position)
    assert_equal "principal", create_invitation(kind: "school_staff", contact: "0700000025", position: "principal").reload.position
    assert_nil create_invitation(kind: "school_staff", contact: "0700000026", position: nil).reload.position
    assert_raises(ActiveRecord::CheckViolation) do
      Orm::Invitation.transaction(requires_new: true) do
        create_invitation(kind: "school_staff", contact: "0700000027", position: "head")
      end
    end
  end

  test "the migration reruns both ways without failing" do
    migrate(:down)
    migrate(:down)
    migrate(:up)
    migrate(:up)

    assert_includes Orm::SchoolStaff.column_names, "position"
    assert_raises(ActiveRecord::NotNullViolation) do
      Orm::SchoolStaff.transaction(requires_new: true) { Orm::SchoolStaff.find_by!(user: create_school_admin).update_columns(position: nil) }
    end
  end
end
