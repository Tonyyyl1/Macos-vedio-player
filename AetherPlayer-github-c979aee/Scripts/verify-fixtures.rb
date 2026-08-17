#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "optparse"
require "yaml"

project_root = File.expand_path("..", __dir__)
options = {
  manifest: File.join(project_root, "compatibility", "manifest.yaml"),
  fixtures: File.join(project_root, "Fixtures"),
  include_planned: false
}

OptionParser.new do |parser|
  parser.banner = "Usage: verify-fixtures.rb [options]"
  parser.on("--manifest PATH", "Manifest YAML path") { |value| options[:manifest] = value }
  parser.on("--fixtures PATH", "Fixture directory") { |value| options[:fixtures] = value }
  parser.on("--include-planned", "Report planned entries as missing") { options[:include_planned] = true }
end.parse!

manifest = YAML.safe_load(File.read(options[:manifest]), permitted_classes: [], aliases: false)
fixtures = manifest.fetch("fixtures")
failures = []
checked = 0
planned = 0

container_formats = {
  "mp4" => "mp4",
  "mov" => "mov",
  "mkv" => "matroska",
  "webm" => "webm"
}.freeze

def probe(path)
  stdout, stderr, status = Open3.capture3(
    "ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", path
  )
  raise "ffprobe failed: #{stderr.strip}" unless status.success?

  JSON.parse(stdout)
end

fixtures.each do |entry|
  status = entry.fetch("status")
  if status != "ready"
    planned += 1
    next unless options[:include_planned]
  end

  id = entry.fetch("id")
  path = File.join(options[:fixtures], entry.fetch("file"))
  unless File.file?(path)
    failures << "#{id}: fixture missing at #{path}"
    next
  end

  checked += 1
  begin
    metadata = probe(path)
    if entry["expectedFailure"]
      failures << "#{id}: expected #{entry["expectedFailure"]}, but ffprobe accepted the fixture"
      next
    end
    format_names = metadata.fetch("format").fetch("format_name").split(",")
    expected_format = container_formats.fetch(entry.fetch("container"))
    failures << "#{id}: expected #{expected_format} container, got #{format_names.join(",")}" unless format_names.include?(expected_format)

    streams = metadata.fetch("streams")
    video = streams.find { |stream| stream["codec_type"] == "video" }
    audio = streams.find { |stream| stream["codec_type"] == "audio" }
    subtitle = streams.find { |stream| stream["codec_type"] == "subtitle" }

    if entry["videoCodec"]
      failures << "#{id}: expected video codec #{entry["videoCodec"]}" unless video&.fetch("codec_name", nil) == entry["videoCodec"]
    end
    if entry["videoProfile"]
      failures << "#{id}: expected video profile #{entry["videoProfile"]}" unless video&.fetch("profile", nil) == entry["videoProfile"]
    end
    if entry["videoColorSpace"]
      failures << "#{id}: expected video colour space #{entry["videoColorSpace"]}" unless video&.fetch("color_space", nil) == entry["videoColorSpace"]
    end
    if entry["videoColorTransfer"]
      failures << "#{id}: expected video colour transfer #{entry["videoColorTransfer"]}" unless video&.fetch("color_transfer", nil) == entry["videoColorTransfer"]
    end
    if entry["videoColorPrimaries"]
      failures << "#{id}: expected video colour primaries #{entry["videoColorPrimaries"]}" unless video&.fetch("color_primaries", nil) == entry["videoColorPrimaries"]
    end
    if entry["audioCodec"]
      failures << "#{id}: expected audio codec #{entry["audioCodec"]}" unless audio&.fetch("codec_name", nil) == entry["audioCodec"]
    end
    if entry["subtitleCodec"]
      failures << "#{id}: expected subtitle codec #{entry["subtitleCodec"]}" unless subtitle&.fetch("codec_name", nil) == entry["subtitleCodec"]
    end
    if entry["expectedSeekable"] && metadata.fetch("format").fetch("duration", "0").to_f <= 0
      failures << "#{id}: seekable fixture must have a positive duration"
    end
  rescue StandardError => error
    if entry["expectedFailure"]
      # An intentionally malformed fixture passes verification only when the
      # probe rejects it. Playback-state behavior is asserted in XCTest.
      next
    end
    failures << "#{id}: #{error.message}"
  end
end

puts "Fixture probe: #{checked} checked, #{planned} planned, #{failures.length} failed"
failures.each { |failure| warn "FAIL: #{failure}" }
exit(failures.empty? ? 0 : 1)
