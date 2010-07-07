if defined?(RAILS_ENV) && RAILS_ENV == 'test'
  require 'test/unit'
  ::ActiveSupport::TestCase.send(:include, ::CreateValid::TestIntegration)
  
  if File.exists?(RAILS_ROOT + '/test/factory.rb')
    ::CreateValid::KludgyEvalContext.new.instance_eval(File.read(RAILS_ROOT + '/test/factory.rb'))
  end
end