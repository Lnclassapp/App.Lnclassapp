# Pure Ruby, no Rails boot: migrations in two steps (conventions.md §7, chantier acceleration-du-flux). Rolling back to
# the previous image never rolls back a migration, so the old code must run on the new schema: a delivery never removes
# what it adds or copies. A delivery is the set of migrations absent from origin/main, the ones the next promotion to
# main deploys; when git cannot compare, every migration of the repository is checked.
require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

module MigrationRules
  RULE = "docs/guide/conventions.md §7 (migrations en deux temps)".freeze
  EXCEPTION = /^\s*#\s*migration-en-deux-temps:[ \t]*\S/
  NAME = /[:"']?(\w+)["']?/
  ARG = /,\s*#{NAME}/

  module_function

  def clean_git_env = ENV.keys.grep(/\AGIT_/).to_h { [ it, nil ] }

  # → [paths, compared]: the migrations of the delivery, and whether git could compare with origin/main.
  def delivery(root)
    all = Dir[File.join(root, "db/migrate/*.rb")].sort
    deployed, status = Open3.capture2(clean_git_env, "git", "-C", root, "ls-tree", "--name-only", "origin/main", "db/migrate/", err: File::NULL)
    return [ all, false ] unless status.success?

    known = deployed.lines.map { File.basename(it.strip) }
    [ all.reject { known.include?(File.basename(it)) }, true ]
  end

  # The code a migration plays going forward: full-line comments and the `down` direction left out.
  def forward(source)
    lines = []
    closing = nil
    source.each_line do |line|
      if closing
        closing = nil if line.match?(closing)
        next
      end
      next if line.match?(/^\s*#/)

      if (down = line.match(/^(\s*)(?:def\s+(?:self\.)?down\b|.*\b\w+\.down\s*(?:do\b|\{))/))
        closing = /^#{down[1]}end\b/ unless line.match?(/\bdef\s+(?:self\.)?down\s*=|\.down\s*\{.*\}|\bend\s*$/)
        next
      end
      lines << line
    end
    lines.join
  end

  # → [[table, column or nil for the whole table]] the forward code removes.
  def removed(code)
    gone = []
    code.scan(/\bremove_columns?[\s(]+#{NAME}((?:#{ARG})+)/) { |table, rest| rest.scan(/#{ARG}/) { gone << [ table, it[0] ] } }
    code.scan(/\bremove_(?:reference|belongs_to)[\s(]+#{NAME}#{ARG}/) { |table, ref| gone << [ table, "#{ref}_id" ] }
    code.scan(/\brename_column[\s(]+#{NAME}#{ARG}/) { |table, column| gone << [ table, column ] }
    code.scan(/\b(?:drop_table|rename_table)[\s(]+#{NAME}/) { gone << [ it[0], nil ] }
    code.scan(/^([ \t]*)change_table[\s(]+#{NAME}[^\n]*\|(\w+)\|\n(.*?)^\1end\b/m) do |_, table, var, body|
      body.scan(/\b#{var}\.remove[\s(]+#{NAME}((?:#{ARG})*)/) do |first, rest|
        gone << [ table, first ]
        rest.scan(/#{ARG}/) { gone << [ table, it[0] ] }
      end
      body.scan(/\b#{var}\.rename[\s(]+#{NAME}/) { gone << [ table, it[0] ] }
      body.scan(/\b#{var}\.remove_(?:references|belongs_to)[\s(]+#{NAME}/) { gone << [ table, "#{it[0]}_id" ] }
    end
    # The same operations written in SQL.
    table = /\bALTER\s+TABLE\s+(?:IF\s+EXISTS\s+)?"?(\w+)"?\s+/i
    code.scan(/#{table}DROP\s+(?!CONSTRAINT\b|DEFAULT\b|NOT\b|IDENTITY\b|EXPRESSION\b)(?:COLUMN\s+)?(?:IF\s+EXISTS\s+)?"?(\w+)/i) do
      gone << it
    end
    code.scan(/#{table}RENAME\s+(?!CONSTRAINT\b)(?:COLUMN\s+)?"?(\w+)/i) { |name, column| gone << [ name, column.casecmp?("to") ? nil : column ] }
    code.scan(/\bDROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?"?(\w+)/i) { gone << [ it[0], nil ] }
    gone.reject { %w[if_exists type].include?(it[1]) }.uniq
  end

  # Does the forward code create, add or copy the column (table, column), or touch the table when column is nil?
  def adds_or_copies?(code, table, column)
    t = Regexp.escape(table)
    return true if code.match?(/\bcreate_table[\s(]+[:"']?#{t}["']?\W/) || code.match?(/\brename_table[\s(]+#{NAME},\s*[:"']?#{t}["']?\W/)
    if column.nil?
      return code.match?(/\b(?:add_column|add_reference|add_belongs_to|change_table)[\s(]+[:"']?#{t}["']?\W/) ||
             code.match?(/\b(?:FROM|JOIN|INTO|UPDATE)\s+"?#{t}\b/i) || code.match?(/\b#{t}\.[a-z_]/)
    end

    c = Regexp.escape(column)
    reference = Regexp.escape(column.delete_suffix("_id"))
    code.match?(/\badd_column[\s(]+[:"']?#{t}["']?,\s*[:"']?#{c}["']?\W/) ||
      code.match?(/\badd_(?:reference|belongs_to)[\s(]+[:"']?#{t}["']?,\s*[:"']?#{reference}["']?\W/) ||
      code.match?(/\brename_column[\s(]+[:"']?#{t}["']?#{ARG},\s*[:"']?#{c}["']?\W/) ||
      code.match?(/\b#{t}\.#{c}\b/) || in_change_table?(code, t, c, reference) ||
      # An unqualified copy: `UPDATE table SET … column …`, or `update_all` naming the column.
      code.match?(/\bUPDATE\s+"?#{t}"?\s+SET\b[^;"]*\b#{c}\b/i) || code.match?(/\bupdate_all[\s(]+[^)\n]*\b#{c}\b/)
  end

  # `t.string :column` or `t.references :reference` inside `change_table :table do |t|`.
  def in_change_table?(code, table, column, reference)
    code.scan(/^([ \t]*)change_table[\s(]+[:"']?#{table}["']?[^\n]*\|(\w+)\|\n(.*?)^\1end\b/m).any? do |_, var, body|
      body.match?(/\b#{var}\.(?:references|belongs_to)[\s(]+[:"']?#{reference}["']?\W/) ||
        body.match?(/\b#{var}\.(?!remove|rename)\w+[\s(]+[:"']?#{column}["']?\W/)
    end
  end

  # → the messages, one per removal that its own delivery creates, adds or copies.
  def violations(paths, root:)
    relative = ->(file) { file.delete_prefix("#{root}/") }
    codes = paths.to_h { [ it, forward(File.read(it)) ] }
    paths.reject { File.read(it).match?(EXCEPTION) }.flat_map do |path|
      removed(codes[path]).filter_map do |table, column|
        sources = codes.select { |_, code| adds_or_copies?(code, table, column) }.keys
        next if sources.empty?

        label = column ? "#{table}.#{column}" : "la table #{table}"
        "#{relative.(path)} supprime #{label}, que la même livraison crée, ajoute ou recopie " \
          "(#{sources.map(&relative).join(', ')}). Règle : #{RULE}. " \
          "Exception : « # migration-en-deux-temps: <raison> » dans la migration qui supprime."
      end
    end
  end
end

class MigrationRulesTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  COPY = <<~RUBY.freeze
    class CreateTeacherSchoolMaterials < ActiveRecord::Migration[8.1]
      def up
        create_table :teacher_school_materials do |t|
          t.bigint :material_id, null: false
        end
        execute "INSERT INTO teacher_school_materials (material_id) SELECT teacher_profiles.material_id FROM teacher_profiles"
      end

      def down = drop_table(:teacher_school_materials)
    end
  RUBY
  REMOVE = <<~RUBY.freeze
    class RemoveMaterialIdFromTeacherProfiles < ActiveRecord::Migration[8.1]
      def up
        remove_column :teacher_profiles, :material_id
      end

      def down
        add_reference :teacher_profiles, :material
      end
    end
  RUBY

  # The real db/migrate/, against the real origin/main (every migration when git cannot compare).
  def test_the_delivery_of_this_branch_adds_or_copies_nothing_it_removes
    paths, = MigrationRules.delivery(ROOT)

    assert_empty MigrationRules.violations(paths, root: ROOT)
  end

  # Done of lot B: a branch that replays PR #268 (its two real migrations, in one delivery) is refused.
  def test_a_branch_that_replays_pr_268_is_refused
    in_repository do |repo|
      %w[20261016160000_create_teacher_school_materials 20261016170000_remove_material_id_from_teacher_profiles].each do |name|
        FileUtils.cp(File.join(ROOT, "db/migrate/#{name}.rb"), File.join(repo, "db/migrate"))
      end

      messages = violations(repo)
      assert_equal 1, messages.size, messages.join("\n")
      assert_match %r{\Adb/migrate/20261016170000_remove_material_id_from_teacher_profiles\.rb supprime teacher_profiles\.material_id,},
                   messages.first
      assert_includes messages.first, "(db/migrate/20261016160000_create_teacher_school_materials.rb)"
      assert_includes messages.first, "docs/guide/conventions.md §7"
    end
  end

  def test_an_addition_or_a_copy_then_a_removal_in_one_delivery_is_refused
    [
      [ "add_column :lessons, :summary, :text", "remove_column :lessons, :summary" ],
      [ "add_reference :lessons, :material, foreign_key: true", "remove_reference :lessons, :material" ],
      [ "change_table :lessons do |t|\n    t.string :slug\n  end", "remove_columns :lessons, :title, :slug" ],
      [ "execute \"UPDATE lessons SET body = old_lessons.body FROM old_lessons\"", "drop_table :old_lessons" ],
      [ "create_table :drafts do |t|\n    t.text :body\n  end", "rename_table :drafts, :notes" ],
      [ "add_column :lessons, :heading, :string", "rename_column :lessons, :heading, :title" ],
      [ "add_column :lessons, :summary, :text", "change_table :lessons do |t|\n    t.remove :title, :summary\n  end" ],
      [ "add_column :lessons, :heading, :string", "change_table :lessons do |t|\n    t.rename :heading, :title\n  end" ],
      [ "add_reference :lessons, :material", "change_table :lessons do |t|\n    t.remove_references :material\n  end" ],
      [ "execute \"UPDATE lessons SET summary = body\"", "remove_column :lessons, :body" ],
      [ "Lesson.update_all(\"summary = body\")", "remove_column :lessons, :body" ],
      [ "add_column :lessons, :summary, :text", "execute 'ALTER TABLE lessons DROP COLUMN IF EXISTS summary'" ],
      [ "add_column :lessons, :heading, :string", "execute 'ALTER TABLE lessons RENAME COLUMN heading TO title'" ],
      [ "create_table :drafts", "execute 'DROP TABLE drafts'" ]
    ].each { |first, second| assert_equal 1, delivered(first, second).size, "#{first} / #{second}" }
  end

  def test_another_column_or_an_option_is_not_what_the_delivery_removes
    [
      [ "add_column :lessons, :summary, :text", "remove_column :lessons, :body" ],
      [ "execute \"UPDATE lessons SET summary = lessons.title\"", "remove_column :lessons, :body" ],
      [ "add_column :lessons, :type, :string", "remove_column :lessons, :summary, type: :text" ],
      [ "add_column :notes, :if_exists, :boolean", "remove_column :lessons, :summary, if_exists: true" ],
      [ "execute 'ALTER TABLE lessons ADD COLUMN summary text'", "execute 'ALTER TABLE lessons DROP CONSTRAINT summary_check'" ]
    ].each { |first, second| assert_empty delivered(first, second), "#{first} / #{second}" }
  end

  def test_a_removal_alone_is_accepted
    in_repository do |repo|
      migration(repo, "1_copy", COPY)
      deploy(repo)
      migration(repo, "2_remove", REMOVE)

      assert_empty violations(repo), "la colonne a été vidée dans une livraison précédente"
    end
  end

  def test_the_down_direction_and_the_comments_are_not_the_delivery
    in_repository do |repo|
      migration(repo, "1_add", <<~RUBY)
        # Copied from teacher_profiles.material_id, removed later.
        def up
          add_column :schools, :code, :string
        end

        def down
          remove_column :schools, :code
        end
      RUBY
      migration(repo, "2_other", <<~RUBY)
        def change
          # remove_column :schools, :code
          reversible { |dir| dir.down { remove_column :schools, :code } }
          reversible do |dir|
            dir.down do
              remove_column :schools, :code
            end
          end
        end
      RUBY

      assert_empty violations(repo)
      migration(repo, "3_last", <<~RUBY)
        def change
          reversible { |dir| dir.down { add_column :schools, :name, :string } }
          say "going down" if direction.down?
          remove_column :schools, :code
        end
      RUBY
      assert_equal 1, violations(repo).size, "ce qui suit une ligne « down » reste contrôlé"
    end
  end

  def test_the_two_steps_comment_lifts_the_guard
    in_repository do |repo|
      migration(repo, "1_copy", COPY)
      migration(repo, "2_remove", "# migration-en-deux-temps: table neuve, jamais lue par l'image précédente\n#{REMOVE}")

      assert_empty violations(repo)
      migration(repo, "2_remove", "# migration-en-deux-temps:\n#{REMOVE}")
      assert_equal 1, violations(repo).size, "une exception sans raison ne lève rien"
    end
  end

  def test_when_git_cannot_compare_every_migration_is_checked
    in_repository do |repo|
      migration(repo, "1_copy", COPY)
      migration(repo, "2_remove", REMOVE)
      deploy(repo)

      assert_empty violations(repo), "déjà sur origin/main : hors de la livraison"
      git(repo, "update-ref", "-d", "refs/remotes/origin/main")
      paths, compared = MigrationRules.delivery(repo)

      refute compared
      assert_equal 2, paths.size
      assert_equal 1, violations(repo).size, "sans origin/main, toutes les migrations sont contrôlées"
    end
  end

  private

  def violations(repo) = MigrationRules.violations(MigrationRules.delivery(repo).first, root: repo)

  # The messages for a delivery of two migrations, `first` then `second`.
  def delivered(first, second)
    in_repository do |repo|
      migration(repo, "2_first", "  #{first}\n")
      migration(repo, "3_second", "  #{second}\n")
      violations(repo)
    end
  end

  def migration(repo, name, body) = File.write(File.join(repo, "db/migrate/#{name}.rb"), body)

  def git(repo, *args)
    Open3.capture2e(MigrationRules.clean_git_env, "git", "-C", repo, "-c", "user.name=t", "-c", "user.email=t@t", *args)
  end

  # Everything written so far goes to origin/main.
  def deploy(repo)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "--allow-empty", "-m", "deploy")
    git(repo, "update-ref", "refs/remotes/origin/main", "HEAD")
  end

  # A repository whose origin/main holds an empty db/migrate/.
  def in_repository
    Dir.mktmpdir do |repo|
      FileUtils.mkdir_p(File.join(repo, "db/migrate"))
      git(repo, "init", "-q")
      deploy(repo)
      yield repo
    end
  end
end
