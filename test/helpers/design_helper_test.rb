require "test_helper"

class DesignHelperTest < ActionView::TestCase
  test "design_section frames a component with its API" do
    render inline: <<~ERB
      <%= design_section(id: "buttons", title: "Boutons", api: "ui_button(label)") do %>corps<% end %>
      <%= design_section(id: "colors", title: "Couleurs") do %>teintes<% end %>
    ERB

    assert_select "section#buttons[aria-labelledby=buttons-title] h2#buttons-title", text: "Boutons"
    assert_select "section#buttons code", text: "ui_button(label)"
    assert_select "section#buttons div", text: "corps"
    assert_select "section#colors code", 0
  end

  test "design_example labels a named example" do
    render inline: %(<%= design_example(name: "button-sizes", label: "Tailles") do %><button>ok</button><% end %>)

    assert_select "div[data-example=button-sizes] p", text: "Tailles"
    assert_select "div[data-example=button-sizes] button", text: "ok"
  end
end
