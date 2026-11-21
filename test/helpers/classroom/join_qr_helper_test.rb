require "test_helper"

module Classroom
  class JoinQrHelperTest < ActionView::TestCase
    include JoinQrHelper

    test "renders the SVG of the class link tagged s=qr" do
      svg = class_join_qr_svg("abc123token")
      expected = RQRCode::QRCode.new("http://test.host/c/abc123token?s=qr", level: :m)
                                .as_svg(module_size: 6, use_path: true, viewbox: true, standalone: true, color: "000", fill: "fff")

      assert_predicate svg, :html_safe?
      assert_match(/\A<\?xml|\A<svg/, svg)
      assert_equal expected, svg
    end

    test "encodes the class link and nothing else" do
      captured = nil
      real = RQRCode::QRCode.method(:new)
      stub_method(RQRCode::QRCode, :new, ->(data, **options) { captured = data; real.call(data, **options) }) do
        class_join_qr_svg("abc123token")
      end

      assert_equal "http://test.host/c/abc123token?s=qr", captured
    end
  end
end
