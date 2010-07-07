if defined?(RAILS_ENV) && RAILS_ENV == 'test'
  class ActiveSupport::TestCase
    def method_missing_with_create_valid(method, *args)
      if method.to_s =~ ::CreateValid::MAGIC_METHOD
        ::CreateValid::Factory.new(self).send(method, *args)
      else
        method_missing_without_create_valid(method, *args)
      end
    end
    alias_method_chain :method_missing, :create_valid
  end
  
  Kernel.send(:include, ::CreateValid::GlobalHelpers)
  
  if File.exists?(RAILS_ROOT + '/test/factory.rb')
    ::CreateValid::KludgyEvalContext.new.instance_eval(File.read(RAILS_ROOT + '/test/factory.rb'))
  end
end