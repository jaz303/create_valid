module CreateValid
  MAGIC_METHOD = /^(build|create)_(valid_)?(.*?)(_with_(.*?))?$/
  
  @@registry = Hash.new { |h,k| h[k] = [] }
  @@sequence = 0
  
  def self.next_sequence
    @@sequence += 1
  end
  
  def self.[](key)
    @@registry[key.to_s]
  end
  
  def self.register(model_name, attributes, &block)
    model_name = model_name.to_s.gsub(' ', '_')
    if attributes
      raise ArgumentError, "attributes must be a hash" unless attributes.is_a?(Hash)
      raise ArgumentError, "attributes xor block required" unless block.nil?
      @@registry[model_name] << attributes
    elsif block
      raise ArgumentError, "attributes xor block required" unless attributes.nil?
      @@registry[model_name] << block
    else
      raise ArgumentError, "attributes xor block required"
    end
  end
  
  class Factory
    def initialize(test_case)
      @test_case, @stack = test_case, []
    end
    
    def method_missing(method, *args, &block)
      if method.to_s =~ ::CreateValid::MAGIC_METHOD
        auto_create_instance($3,                            # class name
                             $2 == 'valid_',                # valid?
                             $1 == 'create',                # save to DB?
                             ($5.split('_and_') rescue []), # features to append
                             args.shift || {})              # extra attributes to merge
      else
        super
      end
    end
    
    def instance
      @stack.last
    end
    alias i instance
    
  private
    
    def auto_create_instance(underscored_class_name, require_valid, save, features, extra_attributes)
      returning(underscored_class_name.camelize.constantize.new) do |instance|
        begin
          @stack << instance
          augment(instance, features)
          merge_attributes(instance, extra_attributes)
          assert_validity(instance) if require_valid
          instance.save! if save
        ensure
          @stack.pop
        end
      end
    end
    
    def assert_validity(model)
      if @test_case.is_a?(::Test::Unit::TestCase)
        @test_case.assert(model.valid?)
      elsif @test_case.nil?
        raise "Model invalid" unless model.valid?
      else
        raise "Don't know how to test model validity with an instance of #{test.class.to_s}"
      end
    end
    
    def inheritance_chain(klass)
      returning([]) do |hierarchy|
        while klass != ActiveRecord::Base do
          hierarchy.unshift(klass)
          klass = klass.superclass
        end
      end
    end

    def magic_suffixes_for_features(*features)
      [''] + [features].flatten.map { |f| %(_with_#{f}) }
    end
    
    def augment(instance, features)
      hierarchy = inheritance_chain(instance.class)
      magic_suffixes_for_features(features).each do |suffix|
        hierarchy.each do |klass|
          ::CreateValid["#{klass.name.underscore}#{suffix}"].each do |params|
            if params.is_a?(Proc)
              result = instance_eval(&params)
              merge_attributes(instance, result) if result.is_a?(Hash)
            elsif params.is_a?(Hash)
              merge_attributes(instance, params)
            end
          end
        end
      end
    end
    
    def merge_attributes(instance, attributes)
      # don't use attributes= so we can set protected attributes and associations
      attributes.each { |k,v| instance.send(:"#{k}=", v) }
    end
    
    def next_sequence
      ::CreateValid.next_sequence
    end
  end
  
  module GlobalHelpers
    def next_sequence
      ::CreateValid.next_sequence
    end
    
    def params_for(model, attributes = nil, &block)
      ::CreateValid.register(model, attributes, &block)
    end
  end
  
  module TestIntegration
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.alias_method_chain :method_missing, :create_valid
    end
    
    module InstanceMethods
      def method_missing_with_create_valid(method, *args)
        if method.to_s =~ ::CreateValid::MAGIC_METHOD
          ::CreateValid::Factory.new(self).send(method, *args)
        else
          method_missing_without_create_valid(method, *args)
        end
      end
    end
  end
  
  class KludgyEvalContext
    include GlobalHelpers
  end
end
