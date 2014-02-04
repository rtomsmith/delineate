module Delineate
  module AttributeMap

    # AttributeMap serializer that handles JSON as the external data format.
    class JsonSerializer < MapSerializer

      # Returns the record's mapped attributes as a JSON string. The specified options
      # are passed to the JSON.encode() function.
      def serialize(options = {})
        hash = super()

        if options[:root] == true
          hash = { @record.class.model_name.element.to_sym => hash }
        elsif options[:root]
          hash = { options[:root].to_sym => hash }
        end
        opts = remove_serializer_class_options(options)
        opts.delete(:root)

        hash.to_json(opts)
      end

      # Takes a record's attributes represented as a JSON string, and returns a
      # hash suitable for direct assignment to the record's collection of attributes.
      # For example:
      #
      #   s = ActiveRecord::AttributeMap::JsonSerializer.new(record, :api)
      #   record.attributes = s.serialize_in(json_string)
      #
      def serialize_in(json_string, options = {})
        super(ActiveSupport::JSON.decode(json_string), options)
      end

    end

  end
end
