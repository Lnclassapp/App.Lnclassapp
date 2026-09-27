require "test_helper"

# ADR-0034, UDR-0006, UDR-0034: the materials of the referential — list, creation and edition in the modal frame,
# deletion refused while a course or a teacher uses the material. The colour is the category's, never the name's.
class Teams::MaterialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = create_team_member
  end

  # The badge tone of a category, as ui_subject_badge renders it (CA-26).
  def tone_selector(category)
    tone = ComponentsHelper::SUBJECT_CATEGORIES.fetch(category.to_sym).fetch(:tone)
    ComponentsHelper::BADGE_TONES.fetch(tone).fetch(:chip).split.map { %([class~="#{it}"]) }.join
  end

  def material_params(**overrides)
    { material: { name: "SVT", shortname: "SVT", category: "science" }.merge(overrides) }
  end

  def error_message(attribute, kind)
    I18n.t("activemodel.errors.models.dtos/catalog/material_input.attributes.#{attribute}.#{kind}")
  end

  test "outside the team, every action is refused" do
    material = create_material
    sign_in_as create_teacher

    get materials_path
    assert_response :forbidden
    get new_material_path
    assert_response :forbidden
    post materials_path, params: material_params
    assert_response :forbidden
    get edit_material_path(material.slug)
    assert_response :forbidden
    patch material_path(material.slug), params: material_params
    assert_response :forbidden
    delete material_path(material.slug), as: :turbo_stream
    assert_response :forbidden
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t('errors.codes.forbidden')}/
    assert Orm::Material.exists?(material.id)
  end

  test "the list shows each material by name, its badge in the tone of its category, and its uses" do
    physics = create_material(name: "Physique", shortname: "PC", category: "literature")
    create_material(name: "Anglais", shortname: "Ang", category: "other")
    create_course(material: physics)
    create_teacher(material: physics)
    sign_in_as @member

    get materials_path

    assert_response :success
    assert_select "#materials tr", 2
    assert_select "#materials tr:first-child", text: /Anglais/
    assert_select "#material_physique #{tone_selector('literature')}", text: "Physique"
    assert_select "#material_physique #{tone_selector('science')}", 0
    assert_select "#material_physique td", text: I18n.t("materials.categories.literature")
    assert_select "#material_physique td.tabular-nums", text: "1", count: 2
    assert_select "#material_anglais #{tone_selector('other')}", text: "Anglais"
    assert_select "a[data-turbo-frame=modal][href='#{new_material_path}']"
    assert_select "#material_physique a[data-turbo-frame=modal][href='#{edit_material_path('physique')}']"
    assert_select "#material_physique dialog#delete-material-physique form[action='#{material_path('physique')}'] input[name=_method][value=delete]"
    assert_select "#materials_empty *", 0
  end

  test "an empty referential says so" do
    sign_in_as @member

    get materials_path

    assert_select "#materials tr", 0
    assert_select "#materials_empty", text: /#{I18n.t('teams.materials.index.empty_title')}/
  end

  test "the creation form opens in the modal frame, with a badge preview for each category and none chosen" do
    sign_in_as @member

    get new_material_path, headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "nav", 0
    assert_select "turbo-frame#modal dialog#material-modal form#material-form[action='#{materials_path}']"
    assert_select "input[name='material[name]'][maxlength='40']"
    assert_select "input[name='material[shortname]'][maxlength='10']"
    assert_select "input[type=radio][name='material[category]']", 3
    assert_select "input[type=radio][name='material[category]'][checked]", 0
    assert_select "input[type=radio][name='material[category]'][required]", 0
    Entities::Catalog::Material::CATEGORIES.each do |category|
      assert_select "label:has(input[value=#{category}]) #{tone_selector(category)}", text: I18n.t("materials.categories.#{category}")
    end
  end

  test "without a category, the modal comes back in 422 with its error and the typed values, and nothing is created" do
    sign_in_as @member

    assert_no_difference -> { Orm::Material.count } do
      post materials_path, params: material_params(category: nil), headers: { "Turbo-Frame" => "modal" }
    end

    assert_response :unprocessable_entity
    assert_select "turbo-frame#modal dialog#material-modal[aria-labelledby]"
    assert_select "#material_category_error", text: error_message(:category, :inclusion)
    assert_select "input[type=radio][aria-invalid=true][aria-describedby~=material_category_error]", 3
    assert_select "input[name='material[name]'][value=SVT]"
  end

  test "a created material answers in Turbo Stream: toast, the list in name order, the empty state cleared" do
    create_material(name: "Anglais", shortname: "Ang", category: "literature")
    sign_in_as @member

    post materials_path, params: material_params, as: :turbo_stream

    material = Orm::Material.find_by!(slug: "svt")
    assert_equal [ "SVT", "SVT", "science" ], [ material.name, material.shortname, material.category ]
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t('teams.materials.create.done', name: 'SVT')}/
    assert_select "turbo-stream[action=update][target=materials] tr", 2
    assert_select "turbo-stream[action=update][target=materials] tr:last-child#material_svt #{tone_selector('science')}", text: "SVT"
    assert_select "turbo-stream[action=update][target=materials_empty]"
    assert_equal "taxonomy.changed", Orm::AuditEvent.sole.action
  end

  test "a name or a shortname already taken is refused in the modal, on its field" do
    create_material(name: "SVT", shortname: "Bio", category: "science")
    sign_in_as @member

    post materials_path, params: material_params
    assert_response :unprocessable_entity
    assert_select "#material_name_error", text: error_message(:name, :taken)

    post materials_path, params: material_params(name: "Biologie", shortname: "Bio")
    assert_select "#material_shortname_error", text: error_message(:shortname, :taken)
  end

  test "without Turbo, a created material leads back to the list with a notice" do
    sign_in_as @member

    post materials_path, params: material_params

    assert_redirected_to materials_path
    assert_equal I18n.t("teams.materials.create.done", name: "SVT"), flash[:notice]
  end

  test "the edition form opens in the modal frame with the current values" do
    create_material(name: "SVT", shortname: "SVT", category: "science")
    sign_in_as @member

    get edit_material_path("svt"), headers: { "Turbo-Frame" => "modal" }

    assert_response :success
    assert_select "turbo-frame#modal form#material-form[action='#{material_path('svt')}'] input[name=_method][value=patch]"
    assert_select "input[name='material[name]'][value=SVT]"
    assert_select "input[type=radio][value=science][checked]"
  end

  test "an unknown material has no edition form" do
    sign_in_as @member

    get edit_material_path("latin")
    assert_response :not_found
    patch material_path("latin"), params: material_params
    assert_response :not_found
    delete material_path("latin")
    assert_response :not_found
  end

  test "changing the category changes the badge of the row; renaming keeps the slug and the tone" do
    create_material(name: "SVT", shortname: "SVT", category: "science")
    sign_in_as @member

    patch material_path("svt"), params: material_params(name: "Sciences de la vie"), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t('teams.materials.update.done', name: 'Sciences de la vie')}/
    assert_select "turbo-stream[action=update][target=materials] #material_svt #{tone_selector('science')}", text: "Sciences de la vie"

    patch material_path("svt"), params: material_params(name: "Sciences de la vie", category: "other"), as: :turbo_stream

    assert_select "turbo-stream[action=update][target=materials] #material_svt #{tone_selector('other')}", text: "Sciences de la vie"
    assert_equal [ "svt", "other" ], Orm::Material.sole.then { [ it.slug, it.category ] }
  end

  test "an invalid edition comes back in 422; without Turbo, a valid one leads back to the list" do
    create_material(name: "SVT", shortname: "SVT", category: "science")
    sign_in_as @member

    patch material_path("svt"), params: material_params(shortname: "")
    assert_response :unprocessable_entity
    assert_select "form#material-form[action='#{material_path('svt')}'] #material_shortname_error", text: error_message(:shortname, :blank)

    patch material_path("svt"), params: material_params(category: "literature")
    assert_redirected_to materials_path
    assert_equal "literature", Orm::Material.sole.category
  end

  test "deleting an unused material removes its row; the last one brings back the empty state" do
    create_material(name: "SVT", shortname: "SVT")
    create_material(name: "Latin", shortname: "Lat")
    sign_in_as @member

    delete material_path("svt"), as: :turbo_stream

    assert_response :success
    assert_select "turbo-stream[action=append][target=toasts]", text: /#{I18n.t('teams.materials.destroy.done')}/
    assert_select "turbo-stream[action=remove][target=material_svt]"
    assert_select "turbo-stream[target=materials_empty]", 0

    delete material_path("latin"), as: :turbo_stream

    assert_select "turbo-stream[action=update][target=materials_empty]", text: /#{I18n.t('teams.materials.index.empty_title')}/
    assert_not Orm::Material.exists?
  end

  test "deleting a material used by a course or a teacher is refused with its reason, and the row stays" do
    create_course(material: create_material(name: "SVT", shortname: "SVT"))
    create_teacher(material: create_material(name: "Latin", shortname: "Lat"))
    sign_in_as @member

    %w[svt latin].each do |slug|
      delete material_path(slug), as: :turbo_stream

      assert_response :unprocessable_entity
      assert_select "turbo-stream[action=append][target=toasts] [role=alert]", text: /#{I18n.t('teams.materials.destroy.referenced')}/
      assert_select "turbo-stream[action=replace][target=material_#{slug}] tr#material_#{slug}"
    end
    assert_equal 2, Orm::Material.count
  end

  test "without Turbo, a deletion leads back to the list, with a notice or the reason of the refusal" do
    create_course(material: create_material(name: "SVT", shortname: "SVT"))
    create_material(name: "Latin", shortname: "Lat")
    sign_in_as @member

    delete material_path("latin")
    assert_redirected_to materials_path
    assert_equal I18n.t("teams.materials.destroy.done"), flash[:notice]

    delete material_path("svt")
    assert_redirected_to materials_path
    assert_equal I18n.t("teams.materials.destroy.referenced"), flash[:alert]
  end
end
