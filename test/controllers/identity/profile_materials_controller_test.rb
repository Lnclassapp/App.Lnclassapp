require "test_helper"

# EPM-04 to EPM-10 (ADR-0103 §4.4, UDR-0125 §3.2, §3.3): « Mes matières » opens in the modal frame, checked with the
# subjects of the current school; it answers in Turbo Stream, with an HTML fallback; refusals stay in the modal (422);
# every other role is refused, and nothing is written.
class Identity::ProfileMaterialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @pc = create_material(name: "Physique-Chimie", shortname: "PC")
    @svt = create_material(name: "SVT", shortname: "SVT")
    @maths = create_material(name: "Mathématiques", shortname: "Maths")
    @school = create_school(name: "Lycée A")
    @teacher = create_teacher(school: @school, materials: [ @pc, @svt ])
  end

  def save(*slugs, **options)
    patch profile_materials_path, params: { profile_materials: { material_slugs: [ "", *slugs ] } }, **options
  end

  def list(teacher = @teacher, school = @school)
    Orm::TeacherSchoolMaterial.where(teacher:, school:).in_order.map { it.material.slug }
  end

  test "the profile shows the subjects of the current school, with « Modifier »" do
    sign_in_as @teacher

    get profile_path

    assert_select "#profile_materials dt", "Matières"
    assert_select "#profile_materials dd span", text: "Physique-Chimie"
    assert_select "#profile_materials dd span", text: "SVT"
    assert_select "#profile_materials a[href='#{edit_profile_materials_path}'][data-turbo-frame=modal][aria-label='Modifier mes matières']"
  end

  test "the modal opens in the frame, checked with his subjects" do
    sign_in_as @teacher

    get edit_profile_materials_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal dialog#profile-materials-modal", text: /Mes matières/
    assert_select "form#profile-materials-form[action='#{profile_materials_path}']" do
      assert_select "fieldset legend", text: /Les matières que vous enseignez/
      assert_select "input[type=checkbox][name='profile_materials[material_slugs][]'][checked]", 2
      assert_select "input[type=checkbox][value='#{@maths.slug}']:not([checked])"
    end
    assert_select "p", text: /pour Lycée A/
    assert_select "button[type=submit][form=profile-materials-form]", "Enregistrer"
  end

  test "EPM-04: a third subject answers in Turbo Stream: card replaced, modal closed, toast; audited" do
    sign_in_as @teacher

    save(@pc.slug, @svt.slug, @maths.slug, as: :turbo_stream)

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /Vos matières sont enregistrées\./
    assert_select "turbo-stream[action=update][target=modal]"
    assert_select "turbo-stream[action=replace][target=profile_information] template #profile_materials span", text: "Mathématiques"
    assert_equal [ @pc.slug, @svt.slug, @maths.slug ], list
    assert_equal "profile.materials_changed", Orm::AuditEvent.last.action
  end

  test "without Turbo, the success redirects to the profile with a notice" do
    sign_in_as @teacher

    save(@svt.slug)

    assert_redirected_to profile_path
    assert_equal "Vos matières sont enregistrées.", flash[:notice]
    assert_equal [ @svt.slug ], list
  end

  test "EPM-05: no subject, four subjects, an unknown one: 422 in the modal, nothing written" do
    sign_in_as @teacher
    {
      [] => "Gardez au moins une matière.",
      [ @pc.slug, @svt.slug, @maths.slug, create_material.slug ] => "3 matières au plus.",
      [ "latin" ] => "Cette matière n'existe plus. Rechargez la page."
    }.each do |slugs, message|
      save(*slugs)

      assert_response :unprocessable_content
      assert_select "#profile_materials_material_slugs_error", text: message
      assert_select "input[type=checkbox][aria-invalid=true][aria-describedby*=profile_materials_material_slugs_error]", minimum: 1
    end
    assert_equal [ @pc.slug, @svt.slug ], list
    assert_not Orm::AuditEvent.exists?(action: "profile.materials_changed")
  end

  test "EPM-11: in another school of his, only that school's list changes" do
    other = create_school(name: "Lycée B")
    add_teacher_school(@teacher, other, materials: [ @svt ])
    sign_in_as @teacher
    patch teacher_current_school_path, params: { school_public_id: other.public_id }

    save(@maths.slug)

    assert_equal [ @maths.slug ], list(@teacher, other)
    assert_equal [ @pc.slug, @svt.slug ], list
  end

  test "EPM-08 to EPM-10: a student, a direction and the team are refused, nothing is written" do
    [ create_student, create_school_admin(school: @school), create_team_member ].each do |user|
      sign_in_as user

      get edit_profile_materials_path, headers: { "Turbo-Frame" => "modal" }
      assert_response :forbidden
      assert_select "dialog#profile-materials-modal", 0

      save(@svt.slug)
      assert_response :forbidden
      sign_out
    end
    assert_equal [ @pc.slug, @svt.slug ], list
    assert_not Orm::TeacherSchoolMaterial.where.not(teacher: @teacher).exists?
  end

  test "a visitor is sent to the sign-in" do
    get edit_profile_materials_path

    assert_redirected_to new_session_path
  end
end
