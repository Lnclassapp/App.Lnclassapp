require "test_helper"

# ADR-0073 §4.7, BL-17 : un robot qui se déclare et un préchargement ne sont jamais une lecture.
module Entities
  module Communication
    class ArticleReadTest < ActiveSupport::TestCase
      BROWSER = "Mozilla/5.0 (Linux; Android 10; TECNO KE5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36".freeze

      def countable?(user_agent = BROWSER, headers = {}) = ArticleRead.countable?(user_agent:, headers:)

      test "la page ouverte par un navigateur est une lecture" do
        assert countable?
        assert countable?(BROWSER, { "Sec-Purpose" => nil, "Purpose" => "" })
      end

      test "un robot qui se déclare, ou un agent vide, n'est pas une lecture" do
        [ "Googlebot/2.1", "bingbot", "Mozilla/5.0 (compatible; YandexSpider)", "Yahoo! Slurp", "facebookexternalhit/1.1",
          "WhatsApp/2.23.20.0", "Mozilla/5.0 (Preview)", "curl/8.5.0", "Wget/1.21", "python-requests/2.31",
          "Mozilla/5.0 HeadlessChrome/120.0", "AhrefsBot crawler", "", " ", nil ].each do |user_agent|
          assert_not countable?(user_agent), user_agent.inspect
        end
      end

      test "un préchargement, annoncé par l'un des trois en-têtes, n'est pas une lecture" do
        assert_equal %w[Sec-Purpose X-Sec-Purpose Purpose], ArticleRead::PURPOSE_HEADERS
        [ { "Sec-Purpose" => "prefetch" }, { "Sec-Purpose" => "prefetch;prerender" }, { "X-Sec-Purpose" => "prefetch" },
          { "Purpose" => "Prefetch" } ].each do |headers|
          assert_not countable?(BROWSER, headers), headers.inspect
        end
      end
    end
  end
end
