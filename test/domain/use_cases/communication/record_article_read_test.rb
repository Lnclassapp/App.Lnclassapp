require "test_helper"

module UseCases
  module Communication
    # ADR-0074 §4.7, BL-17 : une lecture est comptée pour un article publié, ouvert par un visiteur ou un compte hors
    # de l'équipe, qui n'est ni un robot qui se déclare ni un préchargement. Un échec du compteur ne lève jamais.
    class RecordArticleReadTest < ActiveSupport::TestCase
      Article = Data.define(:id, :status)
      Actor = Entities::Identity::Actor
      PHONE = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Mobile Safari/537.36".freeze
      # The storage failure the delivery layer declares recoverable (ActiveRecord::ActiveRecordError in production).
      Unavailable = Class.new(StandardError)

      class FakeArticles
        include Ports::Communication::ArticleRepositoryPort

        attr_reader :increments

        def initialize(failure: nil)
          @failure = failure
          @increments = []
        end

        def increment_reads(article_id:)
          raise @failure if @failure

          @increments << article_id
          true
        end
      end

      class FakeReporter
        attr_reader :reports

        def initialize = @reports = []
        def report(error, **options) = @reports << [ error, options ]
      end

      setup do
        @articles = FakeArticles.new
        @reporter = FakeReporter.new
        @published = Article.new(id: 42, status: "published")
      end

      def record(article: @published, actor: nil, user_agent: PHONE, headers: {}, articles: @articles)
        RecordArticleRead.new(articles:, policy: Policies::Communication::ReadArticlePolicy.new, reporter: @reporter,
                              recoverable: Unavailable).call(actor:, article:, user_agent:, headers:)
      end

      test "a visitor's read of a published article is counted, once" do
        result = record

        assert result.success?
        assert result.value
        assert_equal [ 42 ], @articles.increments
      end

      test "a signed-in student, teacher or direction counts as a visitor" do
        [ Actor.new(user_id: 1, role: :student), Actor.new(user_id: 2, role: :teacher),
          Actor.new(user_id: 3, role: :school_admin, school_id: 9) ].each do |actor|
          assert record(actor:).value, actor.role
        end

        assert_equal [ 42, 42, 42 ], @articles.increments
      end

      test "BL-17: a team member never counts, whatever their sub-role, preview included" do
        %w[admin content field].each do |team_role|
          result = record(actor: Actor.new(user_id: 7, role: :team, team_role:))

          assert result.success?, team_role
          assert_not result.value, team_role
        end

        assert_empty @articles.increments
      end

      test "BL-17: a robot that declares itself, or an empty agent, never counts" do
        [ "WhatsApp/2.23.20.0", "facebookexternalhit/1.1", "Googlebot/2.1", "curl/8.5.0", "", nil ].each do |user_agent|
          result = record(user_agent:)

          assert result.success?, user_agent.inspect
          assert_not result.value, user_agent.inspect
        end

        assert_empty @articles.increments
      end

      test "BL-17: a prefetch never counts, whichever of the three headers announces it" do
        %w[Sec-Purpose X-Sec-Purpose Purpose].each do |header|
          assert_not record(headers: { header => "prefetch" }).value, header
        end

        assert_empty @articles.increments
      end

      test "BL-17: a draft or an archived article never counts, read by a visitor or previewed by the team" do
        content = Actor.new(user_id: 7, role: :team, team_role: "content")

        assert_equal :not_found, record(article: Article.new(id: 1, status: "draft")).code
        assert_equal :expired, record(article: Article.new(id: 2, status: "archived")).code
        assert_not record(article: Article.new(id: 1, status: "draft"), actor: content).value
        assert_not record(article: Article.new(id: 2, status: "archived"), actor: content).value
        assert_empty @articles.increments
      end

      test "an article that is no longer published when the counter runs is not counted" do
        articles = FakeArticles.new
        articles.define_singleton_method(:increment_reads) { |article_id:| false }

        assert_not record(articles:).value
      end

      test "a storage failure of the counter never raises: the page is read, the error is reported as handled, with the article" do
        error = Unavailable.new("base indisponible")

        result = record(articles: FakeArticles.new(failure: error))

        assert result.success?
        assert_not result.value
        assert_equal [ [ error, { handled: true, context: { article_id: 42 } } ] ], @reporter.reports
      end

      test "any other error is a bug, not a storage failure: it is neither swallowed nor reported" do
        error = NoMethodError.new("undefined method for nil")

        assert_raises(NoMethodError) { record(articles: FakeArticles.new(failure: error)) }
        assert_empty @reporter.reports
      end
    end
  end
end
