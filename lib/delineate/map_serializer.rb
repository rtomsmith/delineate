module Delineate #:nodoc:

  # The MapSerializer class serves as the base class for processing the
  # reading and writing of ActiveRecord model attributes through an
  # attribute map. Each serializer class supports its own external format
  # for the input/output of the attributes. The format handled by MapSerializer
  # is a hash.
  class MapSerializer

    # Creates a serializer for a single record.
    #
    # The +attribute_map+ parameter can be an AttributeMap instance or the
    # name of the record's attribute map. The +options+ hash is used to
    # filter which attributes and associations are to be serialized for
    # output, and can have the following keys:
    #
    #   :include  Specifies which optional attributes and associations to output.
    #   :only     Restricts the attributes and associations to only those specified.
    #   :except   Processes attributes and associations except those specified.
    #
    # See the description for +mapped_attributes+ for more info about options.
    #
    def initialize(record, attribute_map, options = nil)
      @record = record
      attribute_map = record.send(:attribute_map, attribute_map) if attribute_map.is_a?(Symbol)
      @attribute_map = attribute_map
      @options = options ? options.dup : {}
    end

    # Returns the record's mapped attributes in the serializer's intrinsic format.
    #
    # For the MapSerializer class the attributes are returned as a hash,
    # and the +options+ parameter is ignored.
    def serialize(options = {})
      @attribute_map.resolve! unless @attribute_map.resolved?
      serializable_record
    end

    # Takes a record's attributes in the serializer's intrinsic format, and
    # returns a hash suitable for direct assignment to the record's collection
    # of attributes. For example:
    #
    #   s = ActiveRecord::AttributeMap::MapSerializer.new(record, :api)
    #   record.attributes = s.serialize_in(attrs_hash)
    #
    def serialize_in(attributes, options = {})
      @attribute_map.resolve! unless @attribute_map.resolved?
      @attribute_map.map_attributes_for_write(attributes, options)
    end

    # Returns the record's mapped attributes in the serializer's "internal"
    # format, usually this is a hash.
    def serializable_record
      returning(serializable_record = Hash.new) do
        serializable_attribute_names.each do |name|
          serializable_record[name] = @attribute_map.attribute_value(@record, name)
        end

        add_includes do |association, records, opts|
          polymorphic = @attribute_map.associations[association][:options][:polymorphic]
          assoc_map = association_attribute_map(association)

          if records.is_a?(Enumerable)
            serializable_record[association] = records.collect do |r|
              assoc_map = attribute_map_for_record(r) if polymorphic
              self.class.new(r, assoc_map, opts).serializable_record
            end
          else
            assoc_map = attribute_map_for_record(records) if polymorphic
            serializable_record[association] = self.class.new(records, assoc_map, opts).serializable_record
          end
        end
      end
    end

    protected

      # Returns the list of mapped attribute names that are to be output
      # by applying the serializer's +:include+, +:only+, and +:except+
      # options to the attribute map.
      def serializable_attribute_names
        includes = @options[:include] || []
        includes = [] if includes.is_a?(Hash)
        attribute_names = @attribute_map.serializable_attribute_names(Array(includes))

        if @options[:only]
          @options.delete(:except)
          attribute_names & Array(@options[:only])
        else
          @options[:except] = Array(@options[:except])
          attribute_names - @options[:except]
        end
      end

      # Returns the list of mapped association names that are to be output
      # by applying the serializer's +:include+ to the attribute map.
      def serializable_association_names(includes)
        assoc_includes = includes
        if assoc_includes.is_a?(Array)
          if (h = includes.detect {|i| i.is_a?(Hash)})
            assoc_includes = h.dup
            includes.each { |i| assoc_includes[i] = {} unless i.is_a?(Hash) }
          end
        end

        include_has_options = assoc_includes.is_a?(Hash)
        include_associations = include_has_options ? assoc_includes.keys : Array(assoc_includes)
        associations = @attribute_map.serializable_association_names(include_associations)

        if @options[:only]
          @options.delete(:except)
          associations = associations & Array(@options[:only])
        else
          @options[:except] = Array(@options[:except])
          associations = associations - @options[:except]
        end

        [assoc_includes, associations]
      end

      # Helper for serializing nested models
      def add_includes(&block)
        includes = @options.delete(:include)
        assoc_includes, associations = serializable_association_names(includes)

        for association in associations
          model_assoc = @attribute_map.model_association(association)

          records = case reflection(model_assoc).macro
          when :has_many, :has_and_belongs_to_many
            @record.send(model_assoc).to_a
          when :has_one, :belongs_to
            @record.send(model_assoc)
          end

          yield(association, records, assoc_includes.is_a?(Hash) ? assoc_includes[association] : {}) if records
        end

        @options[:include] = includes if includes
      end

      # Returns an association's attribute map - argument is external name
      def association_attribute_map(association)
        @attribute_map.association_attribute_map(association)
      end

      # Returns the attribute map for the specified record - ensures it
      # is resolved and valid.
      def attribute_map_for_record(record)
        map = record.attribute_map(@attribute_map.name)
        raise(NameError, "Expected attribute map :#{@attribute_map.name} to be defined for class '#{record.class.name}'") if map.nil?
        map.resolve!
      end

      # Gets association reflection
      def reflection(model_assoc)
        klass = @record.class
        reflection = klass.reflect_on_association(model_assoc)
        reflection || (klass.cti_base_class.reflect_on_association(model_assoc) if klass.is_cti_subclass?)
      end

      SERIALIZER_CLASS_OPTIONS = [:include, :only, :except, :context]

      def remove_serializer_class_options(options)
        options.reject {|k,v| SERIALIZER_CLASS_OPTIONS.include?(k)}
      end

  end
end

require 'delineate/serializers/csv_serializer'
require 'delineate/serializers/json_serializer'
require 'delineate/serializers/xml_serializer'
