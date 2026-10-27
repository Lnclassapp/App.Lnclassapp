# ADR-0039 : each import kind is run by its own job, a subclass of Shared::ImportJob
# delivered by the lot of that kind. Names only: Repositories::Catalog::ImportQueue
# resolves them when enqueuing, so a job not merged yet breaks neither boot nor eager_load.
# "classrooms" is not an import kind but a report without a file: the generation of the missing classrooms (ADR-0056).
# "school_codes" and "classroom_links" are reports without a file too: the mass regenerations (ADR-0096).
Rails.application.config.x.import_jobs = {
  "schools" => "School::ImportSchoolsJob",
  "course_tree" => "Catalog::ImportCourseTreeJob",
  "essentials" => "Catalog::ImportEssentialsJob",
  "course_sheet" => "Catalog::ImportCourseSheetJob",
  "exercises" => "Assessment::ImportExercisesJob",
  "classrooms" => "Classroom::GenerateMissingClassroomsJob",
  "drenas" => "School::ImportDrenasJob",
  "school_codes" => "School::RegenerateSchoolCodesJob",
  "classroom_links" => "Classroom::RegenerateClassroomLinksJob"
}.freeze
