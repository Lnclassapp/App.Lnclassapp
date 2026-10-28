require "test_helper"

# contenu-en-blocs (#318), Lot E — l'optique de la position de départ des figures Lentilles : les trois rayons particuliers,
# l'image (réelle ou virtuelle), l'application et les nombres. Les mêmes formules vivent dans lib/course_sheet/lens_geometry.js,
# jugées dans le navigateur par test/system/catalog/course_sheet_lens_test.rb.
class Catalog::CourseSheetLensHelperTest < ActionView::TestCase
  def scene(d:, f:, h: 2) = lens_scene(o: 300, ax: 170, s: 20, w: 560, d:, h:, f:)
  def coords(ray) = ray.to_h.values_at(:x1, :y1, :x2, :y2)

  test "an object beyond the focus gives a real, inverted image after the lens, with three plain rays" do
    result = scene(d: 8, f: 3)
    image = result.image

    assert_equal [ 1, 1, 2, 3, 3 ], result.rays.map(&:ray)
    assert_equal [ false ], result.rays.map(&:virtual).uniq
    assert_in_delta 4.8, image.distance
    assert_in_delta(-0.6, image.gain)
    assert_equal [ 396.0, 194.0, false ], [ image.x, image.y, image.virtual ]
  end

  test "the first ray goes through the focus image, the second through the centre, the third out parallel to the axis" do
    rays = scene(d: 8, f: 3).rays

    # rayon 1 : de B (140, 130) à la lentille à hauteur de B, puis par F′ (360, 170)
    assert_equal [ 140.0, 130.0, 300.0, 130.0 ], coords(rays[0])
    assert_in_delta 170.0, rays[1].y1 + (rays[1].y2 - rays[1].y1) / (rays[1].x2 - rays[1].x1) * (360 - rays[1].x1), 0.05
    # rayon 2 : droit de B à O
    assert_in_delta 170.0, rays[2].y1 + (rays[2].y2 - rays[2].y1) / (rays[2].x2 - rays[2].x1) * (300 - rays[2].x1), 0.05
    # rayon 3 : ressort parallèle à l'axe
    assert_equal rays[4].y1, rays[4].y2
    assert_equal rays[3].y2, rays[4].y1
  end

  test "an object between the lens and the focus gives a virtual, upright, bigger image and dashed prolongations" do
    result = scene(d: 2, f: 4)
    image = result.image

    assert_equal [ 1, 1, 2, 3, 3, 3, 1, 2, 3 ], result.rays.map(&:ray)
    assert_equal 4, result.rays.count(&:virtual)
    assert_in_delta(-4.0, image.distance)
    assert_in_delta 2.0, image.gain
    assert_equal [ 220.0, 90.0, true ], [ image.x, image.y, image.virtual ]
    # les prolongements finissent en B′
    assert_equal [ [ 220.0, 90.0 ] ] * 3, result.rays.select(&:virtual).last(3).map { [ it.x2, it.y2 ] }
    # le rayon 3 en pointillés part du foyer objet F (220, 170)
    assert_equal [ 220.0, 170.0 ], coords(result.rays.find { it.ray == 3 && it.virtual }).first(2)
  end

  test "an object at the focus gives parallel rays and no image" do
    result = scene(d: 3, f: 3)

    assert_nil result.image
    assert_equal [ 1, 1, 2 ], result.rays.map(&:ray)
    assert_nil scene(d: 3.05, f: 3).image
    assert_not_nil scene(d: 3.1, f: 3).image
  end

  test "the application follows the position of the object" do
    assert_equal :magnifier, lens_application(2, 3)
    assert_equal :projector, lens_application(4, 3)
    assert_equal :photo, lens_application(6, 3)
    assert_equal :photo, lens_application(12, 3)
    assert_nil lens_application(3, 3)
  end

  test "the status tells a real, a virtual, an absent and a too distant image apart" do
    assert_equal :real, lens_status(scene(d: 8, f: 3).image)
    assert_equal :virtual, lens_status(scene(d: 2, f: 4).image)
    assert_equal :none, lens_status(scene(d: 3, f: 3).image)
    # d = 3,1 et f = 3 : l'image existe (OA′ = 93 cm) mais sort du dessin, ce n'est ni « absente » ni « réelle »
    far = scene(d: 3.1, f: 3).image
    assert_in_delta 93.0, far.distance
    assert_not lens_image_shown?(far)
    assert_equal :far, lens_status(far)
    assert_equal :far, lens_status(scene(d: 6.9, f: 7).image)
    assert lens_image_shown?(scene(d: 8, f: 3).image)
    assert_not lens_image_shown?(nil)
  end

  test "the size compares the gain to one, with a small margin for the same size" do
    assert_equal :bigger, lens_size(-2)
    assert_equal :bigger, lens_size(1.5)
    assert_equal :smaller, lens_size(-0.6)
    assert_equal :same, lens_size(-1)
    assert_equal :same, lens_size(0.98)
  end

  test "numbers are written the French way, to the tenth" do
    assert_equal "2", lens_number(2)
    assert_equal "2,5", lens_number(2.5)
    assert_equal "1,5", lens_number(1.46)
    assert_equal "0,5", lens_number(0.5)
    assert_equal "12", lens_number(12.04)
  end

  test "the arrow head points away from the axis, whichever side the tip is" do
    assert_equal "100,50 95,60 105,60", lens_head(100, 50, 170)
    assert_equal "100,200 95,190 105,190", lens_head(100, 200, 170)
  end

  test "a parameter out of range, absent or not a number comes back into the range or to its default" do
    assert_in_delta 8.0, lens_param(nil, 8, 0.5..14.5)
    assert_in_delta 8.0, lens_param("huit", 8, 0.5..14.5)
    assert_in_delta 14.5, lens_param(99, 8, 0.5..14.5)
    assert_in_delta 0.5, lens_param(-3, 8, 0.5..14.5)
    assert_in_delta 3.3, lens_param(3.26, 3, 1..7)
  end
end
