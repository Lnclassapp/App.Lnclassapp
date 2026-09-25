# Chrome 154 reports a node that Turbo has just replaced as « Node with given id does not belong to the
# document », an UnknownError that Capybara does not retry, unlike a StaleElementReferenceError. Under a loaded
# machine, sign_in_as and import_flow failed on it (lot R1). Capybara now retries it within its wait, like any
# stale element; an unknown error that lasts still fails once the wait is over.
module DetachedNodeRetry
  def invalid_element_errors
    super + [ ::Selenium::WebDriver::Error::UnknownError ]
  end
end

Capybara::Selenium::Driver.prepend(DetachedNodeRetry)
