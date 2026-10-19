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
