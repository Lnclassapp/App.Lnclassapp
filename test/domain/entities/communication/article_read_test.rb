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

      test "les robots courants se déclarent par « bot » suivi d'un séparateur ; aucun n'est une lecture" do
        [ "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
          "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)", "Mozilla/5.0 (compatible; AhrefsBot/7.0)",
          "DuckDuckBot-Https/1.1; (+https://duckduckgo.com/duckduckbot)", "AdsBot-Google (+http://www.google.com/adsbot.html)",
          "Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)", "Twitterbot/1.0",
          "Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1 Safari/605.1.15 (Applebot/0.1)",
          "Mozilla/5.0 (compatible; Some bot here)" ].each do |user_agent|
          assert_not countable?(user_agent), user_agent
        end
      end

      test "« crawl » suffit à déclarer un robot, sans « bot » ni « spider »" do
        assert_not countable?("Mozilla/5.0 (compatible; SiteCrawler/1.0)")
      end

      test "un téléphone dont le modèle contient « bot » (CUBOT) est une lecture" do
        assert countable?("Mozilla/5.0 (Linux; Android 10; CUBOT X30 Build/QP1A.190711.020) AppleWebKit/537.36 " \
                          "(KHTML, like Gecko) Chrome/120.0.6099.230 Mobile Safari/537.36")
        assert countable?("Mozilla/5.0 (Linux; Android 12; CUBOT KINGKONG 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36")
      end

      test "un préchargement ou un aperçu, annoncé par l'un des quatre en-têtes, n'est pas une lecture" do
        assert_equal %w[Sec-Purpose X-Sec-Purpose Purpose X-Purpose], ArticleRead::PURPOSE_HEADERS
        [ { "Sec-Purpose" => "prefetch" }, { "Sec-Purpose" => "prefetch;prerender" }, { "X-Sec-Purpose" => "prefetch" },
          { "Purpose" => "Prefetch" }, { "X-Purpose" => "preview" }, { "X-Purpose" => "Preview" } ].each do |headers|
          assert_not countable?(BROWSER, headers), headers.inspect
        end
      end
    end
  end
end
