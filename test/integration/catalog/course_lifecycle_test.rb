require "test_helper"

# Chantier catalog-lecture-ecriture-incompatibles (PRD §4.9), CA-05, CA-06, CA-07: a course is created, read, updated,
# published, archived and published again through one entity and one repository — the real adapters, no double.
class Catalog::CourseLifecycleTest < ActiveSupport::TestCase
  setup do
    referential = seed_referential
    @tle = referential[:levels].fetch("tle")
    @d = referential[:series].fetch("d")
    @svt = referential[:materials].fetch("svt")
    @member = create_team_member(second_factor: false)
    @actor = Entities::Identity::Actor.new(user_id: @member.id, role: :team, team_role: "admin")
    @courses = Repositories::Catalog::CourseRepository.new
  end

  def input(**overrides)
    Dtos::Catalog::CourseInput.new(name: "Génétique et évolution", subtitle: "Du gène à l'espèce", level_slug: "tle",
                                   series_slug: "d", material_slug: "svt",
                                   content: "<div><strong>ADN</strong></div><ul><li>Gène</li></ul>", **overrides)
  end

  def use_case(klass)
    policy = Policies::Catalog::ManageContentPolicy.new
    return klass.new(courses: @courses, taxonomy: Repositories::Catalog::TaxonomyRepository.new, policy:) if klass.name.match?(/Create|Update/)

    klass.new(courses: @courses, audit_log: Repositories::Identity::AuditLogRepository.new,
              transaction: Repositories::Shared::Transaction.new, policy:, clock: Time.zone)
  end

  test "create, read, update, publish, archive and publish again one course through the same aggregate" do
    created = use_case(UseCases::Catalog::CreateCourse).call(actor: @actor, dto: input).value
    assert_instance_of Entities::Catalog::Course, created

    read = @courses.find_by_slug(slug: created.slug)
    assert_instance_of Entities::Catalog::Course, read
    assert_equal [ "genetique-et-evolution", "Génétique et évolution", "draft", @member.id, nil ],
                 [ read.slug, read.name, read.status, read.author_id, read.published_at ]
    assert_equal [ @tle.id, @d.id, @svt.id ], [ read.level_id, read.series_id, read.material_id ]
    assert_includes read.content, "<strong>ADN</strong>"

    updated = use_case(UseCases::Catalog::UpdateCourse)
              .call(actor: @actor, slug: read.slug, dto: input(name: "Génétique", series_slug: nil, content: "<div>Nouveau</div>"))
    assert updated.success?
    read = @courses.find_by_slug(slug: "genetique-et-evolution")
    assert_equal [ "Génétique", nil, "draft", "<div>Nouveau</div>" ], [ read.name, read.series_id, read.status, read.content ]

    published = use_case(UseCases::Catalog::PublishCourse).call(actor: @actor, slug: read.slug).value
    first_publication = published.published_at
    assert_equal "published", published.status
    assert_not_nil first_publication

    essential = create_essential(course: Orm::Course.find(read.id))
    assignment = create_assignment(assignable: essential.course)
    archived = use_case(UseCases::Catalog::ArchiveCourse).call(actor: @actor, slug: read.slug).value
    assert_equal "archived", archived.status
    assert_not_nil archived.archived_at
    assert_equal [ "published", "active" ], [ essential.reload.status, assignment.reload.status ]

    republished = use_case(UseCases::Catalog::PublishCourse).call(actor: @actor, slug: read.slug).value
    assert_equal [ "published", nil ], [ republished.status, republished.archived_at ]
    assert_equal first_publication.to_i, republished.published_at.to_i
    assert_equal %w[content.published content.archived content.published], Orm::AuditEvent.order(:id).pluck(:action)
    assert_equal 1, Orm::Course.count
  end

  test "a course never returns to draft: publishing twice or archiving a draft is refused, nothing written" do
    course = use_case(UseCases::Catalog::CreateCourse).call(actor: @actor, dto: input).value

    assert_equal :conflict, use_case(UseCases::Catalog::ArchiveCourse).call(actor: @actor, slug: course.slug).code
    use_case(UseCases::Catalog::PublishCourse).call(actor: @actor, slug: course.slug)
    assert_equal :conflict, use_case(UseCases::Catalog::PublishCourse).call(actor: @actor, slug: course.slug).code
    assert_equal "published", @courses.find_by_slug(slug: course.slug).status
    assert_equal [ "content.published" ], Orm::AuditEvent.pluck(:action)
  end
end
