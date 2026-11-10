# script/ci/record_system_map draws the map of the system tests under SYSTEM_MAP=<dir> (ADR-0127); any other run loads nothing.
require Rails.root.join("script/ci/system_map_recorder").to_s if ENV["SYSTEM_MAP"].to_s.strip != ""
