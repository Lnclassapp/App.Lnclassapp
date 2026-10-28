# The growth budget of the system suite (ADR-0069 §9, decided by the owner on 2026-10-03): a chantier may add at
# most BUDGET seconds of recorded duration to test/system. The suite is 70 % of a run and grew by 13 % in one day
# (2026-10-02); without a budget the ten-minute ceiling gives way by mere growth.
#
# The durations are those of script/ci/test_timings.yml (seconds per file, summed from `-v` runs, GitHub's log at
# each promotion). The growth of a pull request is the sum, over the system files it adds, changes or removes,
# of the recorded duration minus the one recorded on origin/Develop: a file re-recorded on a slower machine
# counts only when the pull request touches it. A system file without a recorded duration is refused: it would
# weigh nothing. test/guards/system_budget_test.rb plays this in the lint group of bin/ci and before each commit.
require "yaml"
require "open3"
require_relative "plan"

class SystemBudget
  BUDGET = 15.0
  # Dérogations du porteur (ADR-0069 §9, amendement du 2026-10-03) : un chantier, ses fichiers système, son budget.
  # Une PR dont tous les fichiers qui grandissent sont ceux d'une dérogation a ce budget-là ; toute autre, BUDGET.
  GRANTS = {
    "blog" => { budget: 20.0, files: %w[test/system/communication/blog_reading_test.rb test/system/teams/blog_management_test.rb] },
    # Amendement du 2026-10-28 : 22 s pour les deux fiches de la phase 2 de contenu-en-blocs (Lentilles, Texte argumentatif).
    "contenu-en-blocs-phase-2" => { budget: 22.0, files: %w[test/system/catalog/course_sheet_lens_test.rb
                                                            test/system/catalog/course_sheet_argument_test.rb] },
    # Amendement du 2026-10-24 : 50 s pour mvp-teacher-student (pilote du 27 octobre). Élargi le 2026-10-26 (porteur) à tous
    # les fichiers système que le chantier touche (53), le budget restant de 50 s.
    "mvp-teacher-student" => { budget: 50.0, files: %w[
      test/system/assessment/remediation_test.rb test/system/assessment/session_result_test.rb
      test/system/assessment/student_progress_test.rb test/system/boucle_pedagogique_test.rb
      test/system/catalog/course_catalog_test.rb test/system/catalog/student_courses_test.rb
      test/system/catalog/teacher_courses_test.rb
      test/system/classroom/assignment_follow_up_desktop_test.rb
      test/system/classroom/assignment_toggle_test.rb test/system/classroom/catalog_assignment_test.rb
      test/system/classroom/classroom_change_test.rb test/system/classroom/classroom_desktop_test.rb
      test/system/classroom/classroom_essential_test.rb
      test/system/classroom/classroom_page_test.rb test/system/classroom/classroom_roster_test.rb
      test/system/classroom/comprehension_test.rb test/system/classroom/daily_exercise_test.rb
      test/system/classroom/join_test.rb test/system/classroom/student_archive_test.rb
      test/system/classroom/student_classroom_test.rb test/system/classroom/student_file_test.rb
      test/system/classroom/student_home_test.rb test/system/classroom/student_removal_test.rb
      test/system/classroom/teacher_first_path_desktop_test.rb test/system/classroom/teacher_home_desktop_test.rb
      test/system/classroom/teacher_home_test.rb
      test/system/classroom/teaching_selection_test.rb test/system/communication/announcements_journey_test.rb
      test/system/communication/announcements_v2_journey_test.rb test/system/communication/help_sheet_test.rb
      test/system/communication/help_test.rb test/system/design_system_test.rb
      test/system/error_paths_test.rb test/system/finitions/catalog_and_student_test.rb
      test/system/finitions/public_pages_test.rb test/system/homepage_test.rb
      test/system/identity/account_panel_test.rb test/system/identity/cold_start_test.rb
      test/system/identity/invite_colleague_test.rb test/system/identity/pin_reveal_test.rb
      test/system/identity/profile_photo_test.rb test/system/identity/profile_pin_test.rb
      test/system/identity/profile_test.rb test/system/identity/school_staff_registration_test.rb
      test/system/identity/student_avatar_menu_test.rb test/system/identity/student_signup_steps_test.rb
      test/system/identity/teacher_materials_test.rb test/system/identity/teacher_registration_desktop_test.rb
      test/system/identity/teacher_signup_test.rb test/system/pwa_offline_test.rb
      test/system/role_homes_test.rb test/system/school/teacher_schools_test.rb
      test/system/shared/teacher_account_panel_desktop_test.rb
    ] }
  }.freeze
  GLOB = "test/system/**/*_test.rb"
  BASE = "origin/Develop"

  class BaseUnavailable < StandardError; end

  attr_reader :files, :timings, :base_timings, :touched

  # files: the system test files; timings: seconds per file now; base_timings: the same on the base;
  # touched: the system test files the change adds, changes or removes.
  def initialize(files:, timings:, base_timings:, touched:)
    @files = files.sort
    @timings = timings
    @base_timings = base_timings
    @touched = touched.sort
  end

  # The system files whose duration nobody recorded.
  def missing = files - timings.keys

  # Seconds added to the suite by the touched files (negative when tests leave).
  def growth = touched.sum { |file| timings.fetch(file, 0.0) - base_timings.fetch(file, 0.0) }.round(1)

  def budget
    growing = touched.select { |file| timings.fetch(file, 0.0) > base_timings.fetch(file, 0.0) }
    grant = GRANTS.each_value.find { |candidate| growing.any? && (growing - candidate[:files]).empty? }
    grant ? grant[:budget] : BUDGET
  end

  def within_budget? = growth <= budget

  def record_command(files) = "bin/rails test #{files.join(' ')} -v 2>&1 | script/ci/record_timings"

  # Reads the repository: the base is origin/Develop, fetched when the checkout does not have it (GitHub checks
  # out one commit). The change compared is the work tree, so an uncommitted test counts before its commit.
  def self.from_git(root: CiPlan::ROOT)
    git = lambda do |*args|
      out, status = Open3.capture2("git", *args, chdir: root, err: File::NULL)
      [ out, status.success? ]
    end
    branch = BASE.delete_prefix("origin/")
    _, found = git.call("rev-parse", "--verify", "--quiet", "#{BASE}^{commit}")
    unless found
      # An explicit refspec: a single-branch checkout would otherwise leave the fetched branch in FETCH_HEAD only.
      git.call("fetch", "--quiet", "--depth=1", "origin", "+refs/heads/#{branch}:refs/remotes/#{BASE}")
      _, found = git.call("rev-parse", "--verify", "--quiet", "#{BASE}^{commit}")
    end
    raise BaseUnavailable, "#{BASE} introuvable : git fetch origin #{branch}" unless found

    base_yaml, present = git.call("show", "#{BASE}:#{CiPlan::TIMINGS.delete_prefix("#{CiPlan::ROOT}/")}")
    merge_base, known = git.call("merge-base", BASE, "HEAD")
    since = known ? merge_base.strip : BASE
    diff, _ = git.call("diff", "--name-only", since, "--", "test/system")
    # A test written but not yet added counts too: the author sees the growth before staging it.
    untracked, _ = git.call("ls-files", "--others", "--exclude-standard", "--", "test/system")

    new(files: CiPlan.files(GLOB), timings: CiPlan.timings,
        base_timings: present ? YAML.safe_load(base_yaml) || {} : {},
        touched: (diff.lines + untracked.lines).map(&:strip).grep(/_test\.rb\z/).uniq)
  end
end
