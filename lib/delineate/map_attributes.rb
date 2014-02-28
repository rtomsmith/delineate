require 'class_inheritable_attributes'

module ActiveRecord

  # Extend the ActiveRecord::Base class to include methods for defining and
  # reading/writing the model API attributes.
  class Base

    # Collection of declared attribute maps for the model class
    class_inheritable_accessor :attribute_maps
    #class_attribute :attribute_maps
    self.attribute_maps = {}

    # The map_attributes method lets an ActiveRecord model class define a set
    # of attributes that are to be exposed through the model's public interface.
    # See the AttributeMap documentation for more information.
    #
    # The map_name parameter names the attribute map, and must be unique within
    # a model class.
    #
    #   class Account < ActiveRecord::Base
    #     map_attributes :api do
    #       .
    #       .
    #     end
    #
    #     map_attributes :csv_export do
    #       .
    #       .
    #     end
    #   end
    #
    # ActiveRecord STI subclasses inherit the attribute map of the same name
    # from their superclass. If you want to include additional subclass attributes,
    # just invoke map_attributes in the subclass and define the extra attributes
    # and associations. If the subclass wants to completely override/replace
    # the superclass map, do:
    #
    #   map_attributes :api, :override => :replace do
    #     .
    #     .
    #   end
    #
    # To access (read) a model instance's attributes via an attribute map,
    # you invoke a method on the instance named <map-name>_attributes. For
    # example:
    #
    #   attrs = post.api_attributes
    #
    # retrieves the attributes as specified in the Post model attribute
    # map named :api. A hash of the API attributes is returned.
    #
    # An optional +options+ parameter lets you include attributes and
    # associations that are defined as :optional in the attribute map.
    # Following are some examples:
    #
    #   post.api_attributes(:include => :author)
    #   post.api_attributes(:include => [:author, :comments])
    #
    # Include the balance attribute and also the description attribute in the
    # :type association:
    #
    #   account.api_attributes(:include => [:balance, {:type => :description}])
    #
    # Another exmpale: in the :type association, include the optional name attribute,
    # the desc attribute of the category association, and all the mapped attributes of
    # the :type association named :assoc2.
    #
    #   account.api_attributes(:include => {:type => [:name, {:category => :desc}, :assoc2]})
    #
    # Other include forms:
    #   :include => :attr1
    #   :include => :assoc1
    #   :include => [:attr1, :attr2, :assoc1]
    #   :include => {:assoc1 => {}, :assoc2 => {:include => [:attr1, :attr2]}}
    #   :include => [:attr1, :attr2, {:assoc1 => {:include => :assoc2}}, :assoc3]
    #
    # In addition to the :include option, you can specify:
    #
    #   :only     Restricts the attributes and associations to only those specified.
    #   :except   Processes attributes and associations except those specified.
    #
    # To update/set a model instance's attributes via an attribute map,
    # you invoke a setter method on the instance named <map_name>_attributes=.
    # For example:
    #
    #   post.api_attributes = attr_hash
    #
    # The input hash contains name/value pairs, including those for nested
    # models as defined as writeable in the attribute map. The input attribute
    # values are mapped to the appropriate model attributes and associations.
    #
    # NOTE: Maps should pretty much be the last thing defined at the class level, but
    # especially after the model class's associations and accepts_nested_attributes_for.
    #
    def self.map_attributes(map_name, options = {}, &blk)
      map = Delineate::AttributeMap.new(self.name, map_name, options)

      # If this is a CTI subclass, init this map with its base class attributes and associations
      inherit_cti_base_class(map, options) if cti_subclass? && options[:override] != :replace

      # Parse the map specification DSL
      map.instance_eval(&blk)

      # Define the map accessor methods on this class
      define_attribute_map_methods(map_name)

      attribute_maps[map_name] = map
    end

    def self.attribute_map(map_name)
      attribute_maps.try(:fetch, map_name, nil)
    end

    def attribute_map(map_name)
      self.class.attribute_map(map_name)
    end

    # Returns the attributes as specified in the attribut map. The +format+ paramater
    # can be one of the following: :hash, :json, :xml, :csv.
    #
    # The supported options hash keys are:
    #
    #   :include  Specifies which optional attributes and associations to output.
    #   :only     Restricts the attributes and associations to only those specified.
    #   :except   Processes attributes and associations except those specified.
    #   :context  If this option is specified, then attribute readers and writers
    #             defined as symbols will be executed as instance methods on the
    #             specified context object.
    #
    def mapped_attributes(map_name, format = :hash, options = {})
      map = validate_parameters(map_name, format)
      @serializer_context = options[:context]

      serializer_class(format).new(self, map, options).serialize(options)
    end

    # Sets the model object's attributes from the input hash. The hash contains
    # name/value pairs, including those for nested models as defined as writeable
    # in the attribute map. The input attribute names are mapped to the appropriate
    # model attributes and associations.
    #
    def mapped_attributes=(map_name, attrs, format = :hash, options = {})
      map = validate_parameters(map_name, format)
      @serializer_context = options[:context]

      self.attributes = serializer_class(format).new(self, map).serialize_in(attrs, options)
    end
    alias_method :set_mapped_attributes, :mapped_attributes=

    private

      # Defines the attribute map accessor methods:
      #
      #   def api_attributes([format = :hash,] options = {})    # returns the mapped attributes as a hash
      #   def api_attributes=(attr_hash, options={})            # sets model attributes via the map
      #
      def self.define_attribute_map_methods(map_name)
        class_eval do
          define_method("#{map_name}_attributes") do |*args|
            format = args.first && args.first.is_a?(Symbol) ? args.first : :hash
            options = args.last.is_a?(Hash) ? args.last : {}
            mapped_attributes(map_name, format, options)
          end

          define_method("#{map_name}_attributes=") do |attr_hash|
            set_mapped_attributes(map_name, attr_hash, :hash)
          end
        end
      end

      # Returns true if this AR class is a CTI subclass.
      def self.cti_subclass?
        respond_to?(:is_cti_subclass?) and is_cti_subclass?
      end

      # Initialize this map with its CTI base class attributes and associations
      def self.inherit_cti_base_class(map, options)
        base_class_map = cti_base_class.attribute_map(map.name)
        raise "Base class for CTI subclass #{self.name} must specify attribute map #{map.name}" unless base_class_map

        map.copy(base_class_map)
        map.associations.delete_if {|k, a| a[:klass_name] == self.name}
        map.instance_variable_set(:@resolved, false)
      end

      def serializer_class(format)
        if format == :hash
          Delineate::MapSerializer
        else
          "Delineate::Serializers::#{format.to_s.camelize}Serializer".constantize
        end
      end

      def validate_parameters(map_name, format)
        map = map_name
        if map_name.is_a? Symbol
          map = attribute_map(map_name)
          raise ArgumentError, "Missing attribute map :#{map_name} for class #{self.class.name}" if map.nil?
        end

        raise ArgumentError, "The map parameter :#{map_name} for class #{self.class.name} is invalid" if !map.is_a?(Delineate::AttributeMap)
        raise ArgumentError, 'Invalid format parameter' unless [:hash, :csv, :xml, :json].include?(format)
        map
      end

  end

end
