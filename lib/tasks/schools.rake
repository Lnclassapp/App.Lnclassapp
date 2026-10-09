# Réparation unique (import-second-cycle-force) : donne le second cycle aux établissements importés au premier cycle seul.
# Rejouable ; à lancer une fois par environnement : bin/rails schools:grant_second_cycle
namespace :schools do
  desc "Passe les établissements au premier cycle seul en « both » et génère leurs classes du second cycle"
  task grant_second_cycle: :environment do
    summary = UseCases::School::GrantSecondCycle.new(
      schools: Repositories::School::SchoolRepository.new, classrooms: Repositories::Classroom::ClassroomRepository.new,
      taxonomy: Repositories::Catalog::TaxonomyRepository.new, classroom_plan: Repositories::Classroom::ClassroomPlanRepository.new,
      transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call.value
    puts "#{summary.schools} établissements réparés, #{summary.classrooms} classes créées, #{summary.failed.size} en échec"
    puts "En échec : #{summary.failed.join(', ')}" if summary.failed.any?
  end
end
