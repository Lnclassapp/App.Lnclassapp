# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

run Rails.application
Rails.application.load_server

# ESSAI JETABLE ci-rapide : offense Rubocop
ESSAI_CI_RAPIDE = [1,2].freeze
