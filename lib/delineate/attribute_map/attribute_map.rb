module Delineate

  module AttributeMap

  # == Attribute Maps
  #
  # The AttributeMap class provides the ability to expose an ActiveRecord model's
  # attributes and associations in a customized way. By speciying an attribute map,
  # the model's internal attributes and associations can be de-coupled from its
  # presentation or interface, allowing a consumer's interaction with the model to
  # remain consistent even if the model implementation or schema changes.
  #
  # Note: Although this description contemplates usage of an attribute map in
  # terms of defining an API, multiple attribute maps can be constructed
  # exposing different model interfaces for various use cases.
  #
  # To define an attribute map in an ActiveRecord model, do the following:
  #
  #   class Account < ActiveRecord::Base
  #     map_attributes :api do
  #       attribute :name
  #       attribute :path, :access => :ro
  #       attribute :active, :access => :rw, :using => :active_flag
  #     end
  #   end
  #
  # The map_attributes class method establishes an attribute map that
  # will be used by the model's <map-name>_attributes and <map-name>_attributes= methods.
  # This map specifies the atrribute names, access permissions, and other options
  # as viewed by a user of the model's public API. In the example above, 3 of the
  # the model's attributes are exposed through the API.
  #
  # === Mapping Model Attributes
  #
  # To declare a model attribute be included in the map, you use the attribute
  # method on the AttributeMap instance:
  #
  #   attribute :public_name, :access => :rw, :using => :internal_name
  #
  # The first parameter is required and is the map-specific public name for the
  # attribute. If the :using parameter is not provided, the external name
  # and internal name are assumed to be identical. If :using is specified,
  # the name provided must be either an existing model attribute, or a method
  # that will be called when reading/writing the attribute. In the example above,
  # if internal_name is not a model attribute, you must define methods
  # internal_name() and internal_name=(value) in the ActiveRecord class, the
  # latter being required if the attribute is not read-only.
  #
  # The :access parameter can take the following values:
  #
  # :rw   This value, which is the default, means that the attribute is read-write.
  # :ro   The :ro value designates the attribute as read-only. Attempts to set the
  #       attribute's value will silently fail.
  # :w    The attribute value can be set, but does not appear when the attributes
  #       read.
  # :none Use this option when merging in a map to ignore the attribute defined in
  #       the other map.
  #
  # The :optional parameter affects the reading of a model attribute:
  #
  #   attribute :balance, :access => :ro, :optional => true
  #
  # Optional attributes are not accessed/included when retrieving the mapped
  # attributes, unless explicitly requested. This can be useful when there are
  # performance implications for getting an attribute's value, for example. You
  # can specify a symbol as the value for :optional instead of true. The symbol
  # then groups together all attributes with that option group. For example, if
  # you specify:
  #
  #   attribute :balance, :access => :ro, :optional => :compute_balances
  #   attribute :total_balance, :access => :ro, :optional => :compute_balances
  #
  # you then get:
  #
  #   acct.api_attributes(:include => :balance)           # :balance attribute is included in result
  #   acct.api_attributes(:include => :compute_balances)  # Both :balance and :total_balance attributes are returned
  #
  # The :read and :write parameters are used to define accessor methods for
  # the attribute. The specified lambda will be defined as a method named
  # by the :model_attr parameter. For example:
  #
  #   attribute :parent,
  #             :read => lambda {|a| a.parent ? a.parent.path : nil},
  #             :write => lambda {|a, v| a.parent = {:path => v}}
  #
  # Two methods, parent_<map-name>() and parent_<map_name>=(value) will be defined
  # on the ActiveRecord model.
  #
  # === Mapping Model Associations
  #
  # In addition to model attributes, you can specify a model's associations in
  # an attribute map. For example:
  #
  #   class Account < ActiveRecord::Base
  #     :belongs_to :account_type
  #     map_attributes :api do
  #       attribute :name
  #       attribute :path, :access => :ro
  #       association :type, :using => :account_type
  #     end
  #   end
  #
  # The first parameter in the association specification is its mapped name, and
  # the optional :using parameter is the internal association name. In the
  # the example above the account_type association is exposed as a nested object
  # named 'type'.
  #
  # When specifying an association mapping, by default the attribute map in
  # the association's model class is used to define its attributes and nested
  # associations. If you include an attribute defininiton in the association map,
  # it will override the spec in the association model:
  #
  #   class Account < ActiveRecord::Base
  #     :belongs_to :account_type
  #     map_attributes :api do
  #       association :type, :using => :account_type do
  #         attribute :name, :access => :ro
  #         attribute :description, :access => :ro
  #       end
  #     end
  #   end
  #
  # In this example, if the AccountType attribute map declared :name as
  # read-write, the association map in the Account model overrides that to make :name
  # read-only when accessed as a nested object from an Account model. If the
  # :description attribute of AccountType had not been specified in the AccountType
  # attribute map, the inclusion of it here lets that attribute be exposed in the
  # Account attribute map. Note that when overriding an association's attribute, the
  # override must completely re-define the attribute's options.
  #
  # If you want to fully specify an association's attributes, use the
  # :override option as follows:
  #
  #   class Account < ActiveRecord::Base
  #     :belongs_to :account_type
  #     map_api_attributes :account do
  #       association :type, :using => :account_type, :override => :replace do
  #         attribute :name, :access => :ro
  #         attribute :description, :access => :ro
  #         association :category, :access => :ro :using => :account_category
  #           attribute :name
  #         end
  #       end
  #     end
  #   end
  #
  # which re-defines the mapped association as viewed by Account; no merging is
  # done with the attribute map defined in the AccountType model. In the example
  # above, note the ability to nest associations. For this to work, account_category
  # must be declared as an ActiveRecord association in the AccountType class.
  #
  # Other parameters for mapping associations:
  #
  # :access   As with attributes, an association can be declared :ro or :rw (the
  #           default). An association that is writeable will be automatically
  #           specified in an accepts_nested_attributes_for, which allows
  #           attribute writes to contain a nested hash for the association
  #           (except for individual association attributes that are read-only).
  #
  # :optional When set to true, the association is not included by default when
  #           retrieving/returning the model's mapped attributes.
  #
  # :polymorphic  Affects reading only and is relevant when the association class
  #           is an STI base class. When set to true, the attribute map of
  #           each association record (as defined by its class) is used to
  #           specify its included attributes and associations. This means that
  #           in a collection association, the returned attribute hashes may be
  #           heterogeneous, i.e. vary according to each retrieved record's
  #           class. NOTE: when using :polymorphic, you cannot merge/override
  #           the association class attribute map.
  #
  # === STI Attribute Maps
  #
  # ActiveRecord STI subclasses inherit the attribute maps from their superclass.
  # If you want to include additional subclass attributes, just invoke
  # map_attributes in the subclass and define the extra attributes and
  # associations. If the subclass wants to completely override/replace the
  # superclass map, do:
  #
  #   class MySubclass < MyBase
  #     map_attributes :api, :override => :replace do
  #       .
  #       .
  #     end
  #   end
  #
  class AttributeMap
    attr_reader   :klass_name
    attr_reader   :name
    attr_accessor :attributes
    attr_accessor :associations

    # The klass constructor parameter is the ActiveRecord model class for
    # the map being created.
    def initialize(klass_name, name, options = {})
      @klass_name = klass_name
      @name = name
      @options = options
      validate_map_options(options)

      @attributes = {}
      @associations = {}
      @write_attributes = {:_destroy => :_destroy}
      @resolved = false
      @sti_baseclass_merged = false
    end

    # Declare a single attribute to be included in the map. You can declare a list,
    # but the attribute options are limited to :access and :optional.
    def attribute(*args)
      options = args.extract_options!
      validate_attribute_options(options, args.size)

      args.each do |name|
        if options[:access] == :none
          @attributes.delete(name)
          @write_attributes.delete(name)
        else
          @attributes[name] = options

          model_attr = (options[:model_attr] || name).to_sym
          model_attr = define_attr_methods(name, model_attr, options) unless is_model_attr?(model_attr)

          if options[:access] != :ro
            if model_attr.to_s != klass.primary_key && !klass.accessible_attributes.detect { |a| a == model_attr.to_s }
              raise "Expected 'attr_accessible :#{model_attr}' in #{@klass_name}"
            end
            @write_attributes[name] = model_attr
          end
        end
      end
    end

    # Declare an association to be included in the map.
    def association(name, options = {}, &blk)
      validate_association_options(options, block_given?)

      model_attr = (options[:model_attr] || name).to_sym
      reflection = get_model_association(model_attr)

      attr_map = options.delete(:attr_map) || AttributeMap.new(reflection.class_name, @name)
      attr_map.instance_variable_set(:@options, {:override => options[:override]}) if options[:override]

      attr_map.instance_eval(&blk) if block_given?

      if !merge_option?(options) && attr_map.empty?
        raise ArgumentError, "Map association '#{name}' in class #{@klass_name} specifies :replace but has empty block"
      end
      if options[:access] != :ro and !klass.accessible_attributes.include?(model_attr.to_s+'_attributes')
        raise "Expected attr_accessible and/or accepts_nested_attributes_for :#{model_attr} in #{@klass_name} model"
      end

      @associations[name] = {:klass_name => reflection.class_name, :options => options,
                             :attr_map => attr_map.empty? ? nil : attr_map,
                             :collection => (reflection.macro == :has_many || reflection.macro == :has_and_belongs_to_many)}
    end

    # Returns a schema hash according to the attribute map. This information
    # could be used to generate clients.
    #
    # The schema hash has two keys: +attributes+ and +associations+. The content
    # for each varies depeding on the +access+ parameter which can take values
    # of :read, :write, or nil. The +attributes+ hash looks like this:
    #
    #   :read or :write   { :name => :string, :age => :integer }
    #   :nil              { :name => {:type => :string, :access => :rw}, :age => { :type => :integer, :access => :rw} }
    #
    # The +associations+ hash looks like this:
    #
    #   :read or :write   { :posts => {}, :comments => {:optional => true} }
    #   nil               { :posts => {:access => :rw}, :comments => {:optional => true, :access=>:ro} }
    #
    # This method uses the +columns_hash+ provided by ActiveRecord. You can implement
    # that method in your custom models if you want to customize the schema output.
    #
    def schema(access = nil, schemas = [])
      schemas.push(@klass_name)
      resolve

      columns = (klass.is_cti_subclass? ? klass.cti_base_class.columns_hash : {}).merge klass.columns_hash
      attrs = {}
      @attributes.each do |attr, opts|
        attr_type = (column = columns[model_attribute(attr).to_s]) ? column.type : nil
        if (access == :read && opts[:access] != :w) or (access == :write && opts[:access] != :ro)
          attrs[attr] = attr_type
        elsif access.nil?
          attrs[attr] = {:type => attr_type, :access => opts[:access] || :rw}
        end
      end

      associations = {}
      @associations.each do |assoc_name, assoc|
        include_assoc = (access == :read && assoc[:options][:access] != :w) || (access == :write && assoc[:options][:access] != :ro) || access.nil?
        if include_assoc
          associations[assoc_name] = {}
          associations[assoc_name][:optional] = true if assoc[:options][:optional]
        end

        associations[assoc_name][:access] = (assoc[:options][:access] || :rw) if access.nil?

        if include_assoc && assoc[:attr_map] && assoc[:attr_map] != assoc[:klass_name].to_s.constantize.attribute_map(@name)
          associations[assoc_name].merge! assoc[:attr_map].schema(access, schemas) unless schemas.include?(assoc[:klass_name])
        end
      end

      schemas.pop
      {:attributes => attrs, :associations => associations}
    end

    def resolved?
      @resolved
    end

    # Will raise an exception of the map cannot be fully resolved
    def resolve!
      resolve(:must_resolve)
      self
    end

    # Attempts to resolve the map and the maps it depends on. If must_resolve is truthy, will
    # raise an exception if map cannot be resolved.
    def resolve(must_resolve = false, resolving = [])
      return true if @resolved
      return true if resolving.include?(@klass_name)    # prevent infinite recursion

      resolving.push(@klass_name)

      result = resolve_associations(must_resolve, resolving)
      result = false unless resolve_sti_baseclass(must_resolve, resolving)

      resolving.pop
      @resolved = result
    end

    # Values for includes param:
    #   nil = include all attributes
    #   [] = do not include optional attributes
    #   [...] = include the specified optional attributes
    def serializable_attribute_names(includes = nil)
      attribute_names = @attributes.keys.reject {|k| @attributes[k][:access] == :w}
      return attribute_names if includes.nil?

      attribute_names.delete_if do |key|
        (option = @attributes[key][:optional]) && !includes.include?(key) && !includes.include?(option)
      end
    end

    def serializable_association_names(includes = nil)
      return @associations.keys if includes.nil?

      @associations.inject([]) do |assoc_names, assoc|
        assoc_names << assoc.first if !(option = assoc.last[:options][:optional]) || includes.include?(assoc.first) || includes.include?(option)
        assoc_names
      end
    end

    # Given the specified api attributes hash, translates the attribute names to
    # the corresponding model attribute names. Recursive translation on associations
    # is performed. API attributes that are defined as read-only are removed.
    #
    # Input can be a single hash or an array of hashes.
    def map_attributes_for_write(attrs, options = nil)
      raise "Cannot process map #{@klass_name}:#{@name} for write because it has not been resolved" if !resolve

      (attrs.is_a?(Array) ? attrs : [attrs]).each do |attr_hash|
        raise ArgumentError, "Expected attributes hash but received #{attr_hash.inspect}" if !attr_hash.is_a?(Hash)

        attr_hash.dup.symbolize_keys.each do |k, v|
          if assoc = @associations[k]
            map_association_attributes_for_write(assoc, attr_hash, k)
          else
            if @write_attributes.has_key?(k)
              attr_hash.rename_key!(k, @write_attributes[k]) if @write_attributes[k] != k
            else
              attr_hash.delete(k)
            end
          end
        end
      end

      attrs
    end

    def attribute_value(record, name)
      model_attr = model_attribute(name)
      model_attr == :type ? record.read_attribute(:type) : record.send(model_attr)
    end

    def model_association(name)
      @associations[name][:options][:model_attr] || name
    end

    # Access the map of an association defined in this map. Will throw an
    # error if the map cannot be found and resolved.
    def association_attribute_map(association)
      assoc = @associations[association]
      validate(assoc_attr_map(assoc), assoc[:klass_name])
      assoc_attr_map(assoc)
    end

    def validate(map, class_name)
      raise(NameError, "Expected attribute map :#{@name} to be defined for class '#{class_name}'") if map.nil?
      map.resolve! unless map.resolved?
      map
    end

    # Merges another AttributeMap instance into this instance.
    def merge!(other_attr_map, merge_opts = {})
      return if other_attr_map.nil?

      @attributes = @attributes.deep_merge(other_attr_map.attributes)
      @associations.deep_merge!(other_attr_map.associations)

      @write_attributes = {:_destroy => :_destroy}
      @attributes.each {|k, v| @write_attributes[k] = (v[:model_attr] || k) unless v[:access] == :ro}

      @options = other_attr_map.instance_variable_get(:@options).dup if merge_opts[:with_options]
      @resolved = other_attr_map.resolved? if merge_opts[:with_state]

      self
    end

    # Returns a new copy of this AttributeMap instance
    def dup
      returning self.class.new(@klass_name, @name) do |map|
        map.attributes = @attributes.dup
        map.instance_variable_set(:@write_attributes, @write_attributes.dup)
        map.associations = @associations.dup

        map.instance_variable_set(:@resolved, @resolved)
        map.instance_variable_set(:@sti_baseclass_merged, @sti_baseclass_merged)
      end
    end

    def copy(other_map)
      @attributes = other_map.attributes.deep_dup
      @write_attributes = other_map.write_attributes.deep_dup
      @associations = other_map.associations.deep_dup

      map.instance_variable_set(:@resolved, @resolved)
      map.instance_variable_set(:@sti_baseclass_merged, @sti_baseclass_merged)
    end


    protected

      def klass
        @klass ||= @klass_name.constantize
      end

      def empty?
        @attributes.empty? && @associations.empty?
      end

      def model_attribute(name)
        @attributes[name][:model_attr] || name
      end

      def assoc_attr_map(assoc)
        assoc[:attr_map] || assoc[:klass_name].constantize.attribute_map(@name)
      end

      # Map an association's attributes for writing. Will call
      # map_attributes_for_write (resulting in recursion) on the association
      # if it's a has_one or belongs_to, or calls map_attributes_for_write
      # on each element of a has_many collection.
      def map_association_attributes_for_write(assoc, attr_hash, key)
        if assoc[:options][:access] == :ro
          attr_hash.delete(key)       # Writes not allowed
        else
          assoc_attrs = attr_hash[key]
          if assoc[:collection]
            attr_hash[key] = xlate_params_for_nested_attributes_collection(assoc_attrs)

            # Iterate thru each element in the collection and map its attributes
            attr_hash[key].each do |entry_attrs|
              entry_attrs = entry_attrs[1] if entry_attrs.is_a?(Array)
              assoc_attr_map(assoc).map_attributes_for_write(entry_attrs)
            end
          else
            # Association is a one-to-one; map its attributes
            assoc_attr_map(assoc).map_attributes_for_write(assoc_attrs)
          end

          model_attr = assoc[:options][:model_attr] || key
          attr_hash[(model_attr.to_s + '_attributes').to_sym] = attr_hash.delete(key)
        end
      end

      VALID_ASSOC_OPTIONS = [ :model_attr, :using, :override, :polymorphic, :access, :optional, :attr_map ]

      def validate_association_options(options, blk)
        options.assert_valid_keys(VALID_ASSOC_OPTIONS)
        validate_access_option(options[:access])
        options[:model_attr] = options.delete(:using) if options.key?(:using)

        raise ArgumentError, 'Cannot specify :override or provide block with :polymorphic' if options[:polymorphic] and (blk or options[:override])
        raise ArgumentError, 'Option :override must be :replace or :merge' unless !options.key?(:override) || [:merge, :replace].include?(options[:override])
      end

      VALID_ATTR_OPTIONS = [ :model_attr, :access, :optional, :read, :write, :using ]
      VALID_ATTR_OPTIONS_MULITPLE = [ :access, :optional ]

      def validate_attribute_options(options, arg_count = 1)
        options.assert_valid_keys(VALID_ATTR_OPTIONS) if arg_count == 1
        options.assert_valid_keys(VALID_ATTR_OPTIONS_MULITPLE) if arg_count > 1

        options[:model_attr] = options.delete(:using) if options.key?(:using)
        validate_access_option(options[:access])
        raise ArgumentError, 'Cannot specify :write option for read-only attribute' if options[:access] == :ro && options[:write]
      end

      VALID_MAP_OPTIONS = [ :override, :no_primary_key_attr, :no_destroy_attr ]

      def validate_map_options(options)
        options.assert_valid_keys(VALID_MAP_OPTIONS)
        raise ArgumentError, 'Option :override must be :replace or :merge' unless !options.key?(:override) || [:merge, :replace].include?(options[:override])
        if options[:override] == :replace && klass.descends_from_active_record? && !klass.is_cti_subclass?
          raise ArgumentError, "Cannot specify :override => :replace in map_attributes for #{@klass_name} unless it is a CTI or STI subclass"
        end
      end

      def validate_access_option(opt)
        raise ArgumentError, 'Invalid value for :access option' if opt and ![:ro, :rw, :w, :none].include?(opt)
      end

      def get_model_association(association)
        returning association_reflection(association) do |reflection|
          raise ArgumentError, "Association '#{association}' in model #{@klass_name} is not defined yet" if reflection.nil?
          begin
            reflection.klass
          rescue
            raise NameError, "Cannot resolve association class '#{reflection.class_name}' from model '#{@klass_name}'"
          end
        end
      end

      def association_reflection(model_assoc)
        reflection = klass.reflect_on_association(model_assoc)
        reflection || (klass.cti_base_class.reflect_on_association(model_assoc) if klass.is_cti_subclass?)
      end

      def is_model_attr?(name)
        klass.column_names.include?(name.to_s)
      end

      def merge_option?(options)
        options[:override] != :replace
      end

      def resolve_associations(must_resolve, resolving)
        result = true

        @associations.each do |assoc_name, assoc|
          if detect_circular_merge(assoc)
            raise "Detected attribute map circular merge references: class=#{@klass_name}, association=#{assoc_name}"
          end

          assoc_map = assoc[:attr_map] || assoc[:klass_name].constantize.attribute_maps.try(:fetch, @name, nil)
          if assoc_map && !assoc_map.resolved?
            if assoc_map.resolve(must_resolve, resolving) && merge_option?(assoc[:options]) && assoc[:attr_map]
              merge_map = assoc[:klass_name].constantize.attribute_maps[@name]
              assoc_map = merge_map.dup.merge!(assoc_map, :with_options => true, :with_state => true)
            end
          end
          assoc[:attr_map] = assoc_map

          if assoc_map.nil? or !assoc_map.resolve(false, resolving)
            result = false
            raise "Cannot resolve map for association :#{assoc_name} in #{@klass_name}:#{@name} map" if must_resolve
          end
        end

        result
      end

      # If this is the map of an STI subclass, inherit/merge the map from the base class
      def resolve_sti_baseclass(must_resolve, resolving)
        result = true

        if !klass.descends_from_active_record? && !@sti_baseclass_merged && result && @options[:override] != :replace
          if klass.superclass.attribute_maps.try(:fetch, @name, nil).try(:resolve, must_resolve, resolving)
            @resolved = @sti_baseclass_merged = true
            self.copy(klass.superclass.attribute_maps[@name].dup.merge!(self))
          else
            result = false
            raise "Can't resolve base class map for #{@klass_name}:#{@name} map" if must_resolve
          end
        end

        result
      end

      # Checks to see if an assocation specifies a merge, and the association class's
      # attribute map attempts to merge the association parent attribute map.
      def detect_circular_merge(assoc)
        return if assoc.nil? || assoc[:attr_map].nil? || !merge_option?(assoc[:options])
        return unless map = assoc[:klass_name].constantize.attribute_maps.try(:fetch, @name, nil)

        map.associations.each_value do |a|
          return true if a[:klass_name] == @klass_name && merge_option?(a[:options]) && a[:attr_map]
        end

        false
      end

      # Defines custom read/write attribute methods
      def define_attr_methods(name, model_attr, options)
        read_model_attr  = define_attr_reader_method(name, model_attr, options)
        write_model_attr = define_attr_writer_method(name, model_attr, options)

        if read_model_attr || write_model_attr
          options[:model_attr] = read_model_attr || write_model_attr
        else
          model_attr
        end
      end

      def define_attr_reader_method(name, model_attr, options)
        return unless (reader = options[:read])
        raise ArgumentError, 'Invalid parameter for :read' unless (reader.is_a?(Symbol) || reader.is_a?(Proc))

        returning(model_attr == name ? "#{name}_#{@name}" : model_attr) do |method_name|
          if reader.is_a?(Symbol)
            klass.class_eval %(
              def #{method_name}
                if @serializer_context
                  @serializer_context.send(attribute_map(:#{@name}).attributes[:#{name}][:read], self)
                else
                  self.send(attribute_map(:#{@name}).attributes[:#{name}][:read])
                end
              end
            ), __FILE__, __LINE__
          else
            klass.class_eval %(
              def #{method_name}
                attribute_map(:#{@name}).attributes[:#{name}][:read].call(self)
              end
            ), __FILE__, __LINE__
          end
        end
      end

      def define_attr_writer_method(name, model_attr, options)
        return unless (writer = options[:write])
        raise ArgumentError, 'Invalid parameter for :write' unless (writer.is_a?(Symbol) || writer.is_a?(Proc))

        returning(model_attr == name ? "#{name}_#{@name}" : model_attr) do |method_name|
          if writer.is_a?(Symbol)
            klass.class_eval %(
              def #{method_name}=(value)
                if @serializer_context
                  @serializer_context.send(attribute_map(:#{@name}).attributes[:#{name}][:write], self, value)
                else
                  self.send(attribute_map(:#{@name}).attributes[:#{name}][:write], value)
                end
              end
            ), __FILE__, __LINE__
          else
            klass.class_eval %(
              def #{method_name}=(value)
                attribute_map(:#{@name}).attributes[:#{name}][:write].call(self, value)
              end
            ), __FILE__, __LINE__
          end

          klass.attr_accessible method_name
        end
      end

      # The params hash generated from XML/JSON needs to be translated to a form
      # compatible with ActiveRecord nested attributes, specifically with respect
      # to association collections. For example, when the XML input is:
      #
      #   <entries>
      #     <entry>
      #       ... entry 1 stuff ...
      #     </entry>
      #     <entry>
      #       ... entry 2 stuff ...
      #     </entry>
      #   </entries>
      #
      # Rails constructs the resulting params hash as:
      #
      #   {"entries"=>{"entry"=>[{... entry 1 stuff...}, {... entry 2 stuff...}]}}
      #
      # which is incompatible with ActiveRecord nested attrributes. So this method
      # detects that pattern, and translates the above to:
      #
      #   {"entries"=> [{... entry 1 stuff...}, {... entry 2 stuff...}]}
      #
      def xlate_params_for_nested_attributes_collection(assoc_attrs)
        if assoc_attrs.is_a?(Hash) and assoc_attrs.keys.size == 1 and assoc_attrs[assoc_attrs.keys.first].is_a?(Array)
          assoc_attrs[assoc_attrs.keys.first]
        else
          assoc_attrs
        end
      end

  end

  end
end
