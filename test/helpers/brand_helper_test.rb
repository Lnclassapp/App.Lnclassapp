require "test_helper"

# Porteur, 2026-10-08 (ADR-0086, UDR-0082) : le baobab au bras levé sur orange dans la coque enseignants et sur les pages
# des enseignants ; ailleurs, le baobab sur bleu.
class BrandHelperTest < ActionView::TestCase
  attr_accessor :lnclass_app

  test "the blue baobab in a browser and in the students' app" do
    [ nil, :android_student ].each do |app|
      self.lnclass_app = app

      assert_equal "logo/lnclass.jpeg", brand_logo, app.inspect
    end
  end

  test "the teachers' baobab in the teachers' app, and on a teachers' page anywhere" do
    self.lnclass_app = :android_teacher

    assert_equal "logo/lnclass-teacher.jpeg", brand_logo

    self.lnclass_app = nil

    assert_equal "logo/lnclass-teacher.jpeg", brand_logo(teacher: true)
  end
end
