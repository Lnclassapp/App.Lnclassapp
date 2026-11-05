require "test_helper"

# CA-26 (ADR-XXXX modèles de langage, menace du Lot K) : taille, vide et type réel (octets, jamais le type annoncé) sont refusés
# avant toute génération et tout stockage ; un enregistrement valide crée la génération puis met le job en file avec la pièce.
module UseCases
  module Crm
    class SubmitDictationTest < ActiveSupport::TestCase
      class FakeGenerations
        include Ports::Crm::GenerationRepositoryPort

        attr_reader :rows

        def initialize = @rows = []

        def create_pending(generation:)
          return Shared::Result.failure(:conflict) if pending_for(school_id: generation.school_id, kind: generation.kind)

          row = generation.with(public_id: "gen-#{@rows.size + 1}")
          @rows << row
          Shared::Result.success(row)
        end

        def find_by_public_id(public_id:) = @rows.find { it.public_id == public_id }
        def pending_for(school_id:, kind:) = @rows.find { it.school_id == school_id && it.kind == kind && it.pending? }


        attr_accessor :unwritable

        def fail_stale(school_id:, kind:, before:)
          stale = @rows.select { it.pending? && it.school_id == school_id && it.kind == kind && it.created_at && it.created_at < before }
          stale.each { |row| @rows[@rows.index(row)] = row.with(status: "failed", error_code: "timeout") }
          stale.size
        end

        def mark_failed(public_id:, error_code:, duration_ms:)
          return Shared::Result.failure(:not_found) if unwritable

          index = @rows.index { it.public_id == public_id }
          @rows[index] = @rows[index].with(status: "failed", error_code:)
          Shared::Result.success(@rows[index])
        end
      end

      School = Struct.new(:id, :public_id)

      class FakeSchools
        def find_by_public_id(public_id:) = (School.new(7, "school-pub") if public_id == "school-pub")
      end

      # Détecteur d'octets simulé : seuls les premiers octets comptent, jamais un nom ni un type annoncé.
      TYPE_OF = lambda do |io|
        head = io.read(4)
        io.rewind
        { "RIFF" => "audio/x-wav", "WEBM" => "application/x-matroska", "OggS" => "application/ogg", "MP4A" => "audio/mp4", "VMP4" => "video/mp4" }[head]
      end

      def actor(team_role = "field") = Entities::Identity::Actor.new(user_id: 4, role: :team, team_role:)

      def upload(bytes = "WEBM-audio", size: bytes.bytesize) = SubmitDictation::Upload.new(io: StringIO.new(bytes), byte_size: size, content_type: nil)

      setup do
        @generations = FakeGenerations.new
        @enqueued = []
        @accepting = true
        @use_case = SubmitDictation.new(generations: @generations, schools: FakeSchools.new, policy: Policies::Crm::ManageCrmPolicy.new,
                                        type_of: TYPE_OF, enqueue: ->(public_id, stored) { @enqueued << [ public_id, stored ]; @accepting }, logger: Logger.new(@log = StringIO.new))
      end

      def submit(audio = upload, actor: self.actor, school_public_id: "school-pub") = @use_case.call(actor:, school_public_id:, audio:)

      test "a valid recording creates the pending dictation and enqueues it with the audio and its real type" do
        result = submit

        assert result.success?
        assert_equal "dictation", result.value.generation.kind
        assert_predicate result.value.generation, :pending?
        assert_equal 4, result.value.generation.requested_by_id
        assert_equal 1, @enqueued.size
        public_id, stored = @enqueued.first
        assert_equal "gen-1", public_id
        assert_equal "application/x-matroska", TYPE_OF.call(stored.io) # le flux est rendu rembobiné
        assert_equal "audio/webm", stored.content_type
      end

      test "each accepted family is stored under its audio type" do
        { "OggS-x" => "audio/ogg", "MP4A-x" => "audio/mp4", "VMP4-x" => "audio/mp4" }.each do |bytes, type|
          @generations.rows.clear
          submit(upload(bytes))
          assert_equal type, @enqueued.last.last.content_type
        end
      end

      test "CA-26: 12 Mo is refused before any generation or enqueue" do
        result = submit(upload("WEBM", size: 12 * 1024 * 1024))

        assert_equal :invalid, result.code
        assert_equal :too_large, result.errors[:audio]
        assert_empty @generations.rows
        assert_empty @enqueued
      end

      test "exactly 10 Mo is accepted, one byte more is refused" do
        assert submit(upload("WEBM", size: 10 * 1024 * 1024)).success?
        @generations.rows.clear

        assert_equal :too_large, submit(upload("WEBM", size: 10 * 1024 * 1024 + 1)).errors[:audio]
      end

      test "CA-26: a wav recording is refused by its bytes" do
        result = submit(upload("RIFF....WAVEfmt "))

        assert_equal :invalid, result.code
        assert_equal :unsupported_type, result.errors[:audio]
        assert_empty @generations.rows
        assert_empty @enqueued
      end

      test "unknown bytes and an empty file are refused" do
        assert_equal :unsupported_type, submit(upload("<html>")).errors[:audio]
        assert_equal :empty, submit(upload("", size: 0)).errors[:audio]
        assert_empty @generations.rows
      end

      test "the size of the received file is the real one, not the announced one" do
        real = SubmitDictation::Upload.new(io: StringIO.new("WEBM" + ("x" * 20)), byte_size: 24, content_type: nil)

        assert submit(real).success?
      end

      test "a role outside admin and field is forbidden, an unknown school is not found, before any check" do
        assert_equal :forbidden, submit(actor: actor("content")).code
        assert_equal :not_found, submit(school_public_id: "other").code
        assert_empty @generations.rows
      end

      test "a dictation already running for the school is a conflict and nothing is enqueued" do
        submit
        @enqueued.clear

        assert_equal :conflict, submit.code
        assert_empty @enqueued
      end

      test "when the queue refuses, the dictation is marked failed" do
        @accepting = false

        result = submit

        assert result.success?
        assert_predicate result.value.generation, :failed?
        assert_equal "provider_error", result.value.generation.error_code
      end

      test "a stale pending generation is closed and a new request goes through" do
        first = submit.value.generation
        index = @generations.rows.index { it.public_id == first.public_id }
        @generations.rows[index] = first.with(created_at: 10.minutes.ago)
        @enqueued.clear

        result = submit

        assert result.success?
        assert_not_equal first.public_id, result.value.generation.public_id
        assert_equal "timeout", @generations.find_by_public_id(public_id: first.public_id).error_code
        assert_equal [ result.value.generation.public_id ], @enqueued.map(&:first)
      end

      test "when the queue refuses and the failure cannot be written, the request is unavailable and the ids are logged" do
        @accepting = false
        @generations.unwritable = true

        result = submit

        assert_equal :unavailable, result.code
        assert_equal :provider_error, result.errors[:reason]
        assert_includes @log.string, "gen-1"
        assert_includes @log.string, "provider_error"
      end

      test "without a logger, an unwritable refusal is still unavailable" do
        @use_case.instance_variable_set(:@logger, nil)
        @accepting = false
        @generations.unwritable = true

        assert_equal :unavailable, submit.code
      end

      test "a recent pending dictation is still a conflict, and the recording is not enqueued" do
        submit
        @enqueued.clear

        assert_equal :conflict, submit.code
        assert_empty @enqueued
      end
    end
  end
end
