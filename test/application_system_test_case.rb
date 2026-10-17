require "test_helper"
require "selenium-webdriver"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  Selenium::WebDriver.logger.level = :warn

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1100 ] do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
  end

  setup do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia",
      features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
  end
end
