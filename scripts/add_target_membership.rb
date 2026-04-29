#!/usr/bin/env ruby
# Adds keyboard-extension source files to the MoaPlus main app target.
#
# The Xcode project uses Xcode 16 synchronized folders
# (PBXFileSystemSynchronizedRootGroup). The MoaPlusKeyboard folder is the
# canonical home of the keyboard extension target, but a small set of files
# need to be compiled into the MoaPlus app target as well so that Settings/
# screens (e.g. GestureTestView) can use the production engine code.
#
# Cross-target inclusion is expressed via a
# PBXFileSystemSynchronizedBuildFileExceptionSet whose `target` is MoaPlus
# and whose `membershipExceptions` lists each shared path. Existing shared
# files (e.g. KeyboardSettings.swift, ThemeSettings.swift) compile in
# MoaPlus today, confirming the exception set ADDS membership here.
#
# Usage: ruby scripts/add_target_membership.rb

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../../MoaPlus.xcodeproj', __FILE__)
TARGET_NAME = 'MoaPlus'

# Files (relative to the MoaPlusKeyboard synchronized folder) to add to the
# MoaPlus target. GestureTestView and any future Settings screen depending on
# the production gesture engine should pull from this list.
FILES_TO_ADD = [
  'Engine/GestureAnalyzer.swift',
  'Engine/VowelResolver.swift',
  'Models/HangulJamo.swift',
  'Models/GestureDirection.swift',
  'Models/VowelPattern.swift',
  'Models/SwipeProfile.swift',
  'Models/ColumnGestureOverride.swift',
  'Models/KeyboardMode.swift',
  'Utilities/HangulConstants.swift',
  'Utilities/KeyboardMetrics.swift',
  'Utilities/GestureSettings.swift',
]

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME }
raise "Target #{TARGET_NAME} not found" unless target

# Locate the exception set whose target is MoaPlus and lives under the
# MoaPlusKeyboard synchronized root group.
exception_set = project.objects.find do |obj|
  obj.isa.to_s == 'PBXFileSystemSynchronizedBuildFileExceptionSet' &&
    obj.respond_to?(:target) && obj.target == target
end

unless exception_set
  raise "No PBXFileSystemSynchronizedBuildFileExceptionSet found for target #{TARGET_NAME}"
end

current = (exception_set.membership_exceptions || []).dup
puts "Current MoaPlus membership exceptions (#{current.size}):"
current.each { |p| puts "  - #{p}" }
puts ""

added = []
already = []

FILES_TO_ADD.each do |path|
  if current.include?(path)
    already << path
  else
    current << path
    added << path
  end
end

# Keep the list sorted for deterministic diffs.
exception_set.membership_exceptions = current.sort

project.save

puts "Result:"
added.each   { |p| puts "  [added]   #{p}" }
already.each { |p| puts "  [already] #{p}" }
puts ""
puts "Summary: #{added.size} added, #{already.size} already in target."
puts "Total membership exceptions now: #{exception_set.membership_exceptions.size}"
