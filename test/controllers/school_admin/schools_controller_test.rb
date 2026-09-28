require "test_helper"

# ED-04, UDR-0052 §3.1 and §3.7: the « Établissement » page of the direction — its header, the two deferred frames of the
# code (Lot G) and of the staff (Lot B) — in a shell with five active destinations, the detail « <Fonction> · <Établissement> ».
class SchoolAdmin::SchoolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @school = create_school(name: "Lycée Moderne de Treichville", drena: create_drena(name: "Abidjan 2"), school_type: "mixed")
  end

  test "ED-04: a censor opens the page of her school, in the shell of the direction" do
    sign_in_as create_school_admin(school: @school, position: "censor")

    get school_admin_school_path

    assert_response :success
    assert_select "h1", "Lycée Moderne de Treichville"
    assert_select "main p", text: "Abidjan 2 · Mixte"
    # The src is set once the controller of the frame is merged (Lot G: code, Lot B: staff); until then, the skeleton.
    { "school_code" => [ "SchoolAdmin::SchoolCodesController", school_admin_school_code_path ],
      "school_staff" => [ "SchoolAdmin::StaffMembersController", school_admin_staff_members_path ] }.each do |frame, (controller, src)|
      assert_select "turbo-frame##{frame}[loading=lazy]#{controller.safe_constantize ? "[src='#{src}']" : ":not([src])"}"
    end
    assert_select "turbo-frame.aria-busy\\:opacity-50", 2
    assert_select "aside nav" do
      assert_select "a[href]", 5
      assert_select "a[aria-disabled]", 0
      assert_select "a[href='#{school_admin_school_path}'][aria-current=page]", text: /Établissement/
      [ school_admin_home_path, school_admin_classrooms_path, school_admin_teachers_path, school_admin_students_path ].each do |path|
        assert_select "a[href='#{path}']"
      end
    end
    assert_select "aside p", text: "Censeur · Lycée Moderne de Treichville"
  end

  test "the page reads the school of the actor, never an identifier from the address" do
    sign_in_as create_school_admin(school: @school, position: "educator")
    other = create_school(name: "Autre lycée")

    get school_admin_school_path(public_id: other.public_id, school_id: other.id)

    assert_select "h1", "Lycée Moderne de Treichville"
    assert_select "aside p", text: "Éducateur · Lycée Moderne de Treichville"
  end
end
