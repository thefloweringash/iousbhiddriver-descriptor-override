# -*- ruby -*-

directory 'descriptors'

desc "Scan local devices, write ambiguous descriptors to ./descriptors"
task 'scan' => 'descriptors' do
  ruby 'scripts/scanner.rb'
end

desc "Generate fixed overrides from ambiguous descriptors in ./descriptors."
file 'Info.plist' => 'scripts/build-plist.rb'
file 'Info.plist' => 'Info.plist.in'
file 'Info.plist' => Dir['descriptors/*.yaml']
file 'Info.plist' do |t|
  ruby 'scripts/build-plist.rb'
end

desc "Build using xcodebuild"
task 'build' do
  sh *%w{xcodebuild -configuration Release}
end

directory 'tmp/packageroot'
directory 'tmp/packages'
directory 'tmp/resources'
directory 'pkg'

desc "Generate package into ./pkg"
task "package" => ['build', 'tmp/packageroot', 'tmp/packages', 'tmp/resources', 'pkg'] do
  filename = ['IOUSBHIDDriverDescriptorOverride',
              Time.now.strftime('%Y-%m-%d'),
              %x{git rev-parse --short HEAD}.chomp,
             ].join('-') + '.pkg'
  sh %Q{rsync -r -v --exclude '*.dSYM' --delete --delete-excluded \
        build/Release/ tmp/packageroot}
  sh "cp README.md COPYING tmp/resources"
  sh %Q{pkgbuild --root tmp/packageroot \
                  --component-plist dist/Components.plist \
                  --install-location /System/Library/Extensions \
                  tmp/packages/kext.pkg}
  sh %Q{productbuild --distribution dist/distribution.xml \
                     --package-path tmp/packages \
                     --resources "tmp/resources" \
                     pkg/#{filename}}
end
