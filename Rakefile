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
