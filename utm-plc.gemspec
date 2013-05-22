Gem::Specification.new do |s|
  s.name      = "utm-plc"
  s.version   = '0.1.0'
  s.platform  = Gem::Platform::RUBY
  s.date      = Date.today.to_s
  s.authors   = ["Jeff Welling"]
  s.email     = ["jeff.welling@gmail.com"]
  s.homepage  = "https://github.com/jeffWelling/UTM_plc"
  s.summary   = "Tool to check if your UTM's Web Filter is logging"
  s.description="This tool logs in to your UTM and interacts with 'cc' to check the configuration of every web filter configuration in use and list the ones that are not configured to log accessed and blocked pages."

  #s.add_development_dependency "rspec"
  s.files       = Dir.glob("{bin,lib}/*") + %w( LICENSE README )
  s.executables = ['plc']
  s.require_path= 'lib'
end
