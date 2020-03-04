Pod::Spec.new do |s|
  s.name         = 'Subprocess'
  s.version      = '1.0.0'
  s.summary      = 'Wrapper for NSTask used for running processes and shell commands on macOS.'
  s.license      = { :type => 'JAMF', :text => "Copyright (c) #{Time.now.year} JAMF Software, LLC. All rights reserved." }
  s.description  = <<-DESC
                    Everything related to creating processes and running shell commands on macOS.
                   DESC
  s.homepage     = 'https://www.jamf.com/'
  s.authors      = { 'Cyrus Ingraham' => 'cyrus.ingraham@jamf.com' }
  s.source       = { :git => "https://stash.jamf.build/scm/coc/#{s.name.downcase}.git", :tag => s.version.to_s }
  s.platform = :osx, '10.13'
  s.osx.deployment_target = '10.13'
  s.swift_version = '5.1'
  s.default_subspec = 'Core'

  s.subspec 'Core' do |ss|
    ss.source_files = 'Sources/Subprocess/*.swift'
  end

  s.subspec 'Mocks' do |ss|
    ss.source_files = 'Sources/SubprocessMocks/*.swift'
  end

  # s.test_spec 'UnitTests' do |test_spec|
  #   test_spec.source_files = ['UnitTests/*.swift', 'Classes/*.swift']
  #   test_spec.resources = ['UnitTests/TestError', 'UnitTests/TestOutput']
  # end

end
