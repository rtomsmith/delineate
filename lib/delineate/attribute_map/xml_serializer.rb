module Delineate
  module AttributeMap

    # AttributeMap serializer that handles XML as the external data format.
    class XmlSerializer < MapSerializer

      # Returns the record's mapped attributes as XML. The specified options
      # are passed to the XML builder. Some typical options are:
      #
      #   :root
      #   :dasherize
      #   :skip_types
      #   :skip_instruct
      #   :indent
      #
      def serialize(options = {})
        hash = super()

        if options[:root] == true
          root_option = {:root => @record.class.model_name.element}
        elsif options[:root]
          root_option = {:root => options[:root]}
        else
          root_option = {}
        end
        opts = remove_serializer_class_options(options).merge(root_option)

        hash.to_xml(opts)
      end

      # Takes a record's attributes represented in XML, and returns a hash
      # suitable for direct assignment to the record's collection of attributes.
      # For example:
      #
      #   s = Delineate::AttributeMap::XmlSerializer.new(record, :api)
      #   record.attributes = s.serialize_in(xml_string)
      #
      def serialize_in(xml_string, options = {})
        super(Hash.from_xml(xml_string), options)
      end

    end

  end
end
