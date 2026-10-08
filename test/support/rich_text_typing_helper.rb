# Chantier tests-instables-cache-blog: an image lands in the rich text (rich_text_editor_controller inserts it once
# shrunk, then sets its attributes once sent) while the author types, here or in another field. Under a loaded machine
# that is a race; these helpers make it certain: the insertion waits for a given keystroke, and the keys are sent to
# whatever has the focus, one by one, as a person types them (no WebDriver re-focus on the field).
module RichTextTypingHelper
  ActionDispatch::SystemTestCase.include(self)

  HUMAN_KEY_DELAY = 0.1

  # The block drops or picks an image. Trix's insertion of it is held, then let in on the keystroke number `after_keys`
  # in `field` (a selector; the editor itself or another field): it lands at the cursor of the text while that key is
  # typed. Returns once the image is shrunk and held, so the typing that follows always meets it.
  def insert_into_rich_text_on_keystroke(field, after_keys:, editor: "trix-editor")
    page.execute_script(<<~JS, editor, field, after_keys)
      const [editorSelector, fieldSelector, count] = arguments
      const { editor } = document.querySelector(editorSelector)
      const field = document.querySelector(fieldSelector)
      const held = window.heldRichTextInsertions = []
      let keys = 0
      editor.insertFile = (file) => { held.push(file) }
      field.addEventListener("keyup", function release() {
        if (++keys < count) return
        field.removeEventListener("keyup", release)
        delete editor.insertFile
        held.splice(0).forEach((file) => editor.insertFile(file))
      })
    JS
    yield
    page.document.synchronize(20) do
      raise Capybara::ExpectationNotMet, "aucune image retenue avant l'insertion" unless page.evaluate_script("window.heldRichTextInsertions.length > 0")
    end
  end

  def type_like_a_human(text, delay: HUMAN_KEY_DELAY)
    text.each_char { |char| page.driver.browser.action.send_keys(char).pause(duration: delay).perform }
  end

  # The text of the editor as Trix holds it: an attachment is « \uFFFC », a block ends with « \n ».
  def rich_text_content(editor = "trix-editor")
    page.evaluate_script("document.querySelector(arguments[0]).editor.getDocument().toString()", editor)
  end

  def focused_element_id = page.evaluate_script("document.activeElement.id")
end
