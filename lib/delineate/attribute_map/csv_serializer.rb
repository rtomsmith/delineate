require 'csv'

module Delineate
  module AttributeMap

    # AttributeMap serializer that handles CSV as the external data format.
    class CsvSerializer < MapSerializer

      # Returns the record's mapped attributes as a CSV string. If
      # you specify a truthy value for the :include_header option,
      # the CSV header is output as the first line.
      #
      # See the description in +serializable_record+ for the order
      # of the attributes.
      def serialize(options = {})
        opts = options[:include_header] ?
          {:write_headers => true, :headers => serializable_header, :encoding => "UTF-8"} :
          {:encoding => "UTF-8"}

        opts = remove_serializer_class_options(options).merge(opts)
        opts.delete(:include_header)

        CSV.generate(opts) do |csv|
          serializable_record.each {|r| csv << r}
        end
      end

      # Returns the header row as a CSV string.
      def serialize_header(options = {})
        opts = {:encoding => "UTF-8"}.merge(remove_serializer_class_options(options))
        CSV.generate_line(serializable_header, opts)
      end

      # Not implemented yet.
      def serialize_in(csv_string, options = {})
        raise "Serializing from CSV is not supported at this time. You can inherit a class from CsvSerializer to write a custom importer."
      end

      # Returns the record's mapped attributes in the serializer's "internal"
      # format. For this class the representation is an array of one or more
      # rows, one row for each item in teh record's has_many collections. Each
      # row is an array of values ordered as follows:
      #
      #   1. All the record's mapped attributes in map order.
      #   2. All one-to-one mapped association attributes in map order.
      #   3. All one-to-many mapped association attributes in map order
      #
      # Do not specify any method parameters when calling +serializable_record+.
      def serializable_record(prefix = [], top_level = true)
        new_rows = []

        prefix += serializable_attribute_names.map do |name|
          @attribute_map.attribute_value(@record, name)
        end

        add_includes(:one_to_one) do |association, record, opts, nil_record|
          assoc_map = association_attribute_map(association)
          prefix, new_rows = self.class.new(record, assoc_map, opts).serializable_record(prefix, false)
        end

        add_includes(:one_to_many) do |association, records, opts, nil_record|
          assoc_map = association_attribute_map(association)
          records.each do |r|
            p, next_rows = self.class.new(r, assoc_map, opts).serializable_record(prefix, false)
            new_rows << (next_rows.empty? ? p : next_rows) unless nil_record
          end
        end

        top_level ? (new_rows << prefix if new_rows.empty?; new_rows) : [prefix, new_rows]
      end

      # Returns the header row as an array of strings, one for each
      # mapped attribute, including nested assoications. The items
      # appear in the array in the same order as their corresponding
      # attribute values.
      def serializable_header(prefix = '')
        returning(serializable_header = serializable_attribute_names) do
          serializable_header.map! {|h| headerize(prefix + h.to_s)}

          add_includes(:one_to_one) do |association, record, opts|
            assoc_map = association_attribute_map(association)
            assoc_prefix = prefix + association.to_s + '_'
            serializable_header.concat self.class.new(record, assoc_map, opts).serializable_header(assoc_prefix)
          end

          add_includes(:one_to_many) do |association, records, opts|
            assoc_map = association_attribute_map(association)
            assoc_prefix = prefix + association.to_s.singularize + '_'
            serializable_header.concat self.class.new(records.first, assoc_map, opts).serializable_header(assoc_prefix)
          end
        end
      end

      private

        # The diff here is that if the associaton record(s) is empty, we have to generate
        # a new empty record: @record.class.new.build_xxx or @record.class.new.xxx.build
        def add_includes(assoc_type)
          includes = @options.delete(:include)
          assoc_includes, associations = serializable_association_names(includes)

          for association in associations
            model_assoc = @attribute_map.model_association(association)

            case reflection(model_assoc).macro
            when :has_many, :has_and_belongs_to_many
              next if assoc_type == :one_to_one
              records = @record.send(model_assoc).to_a
              records = [@record.class.new.send(model_assoc).build] if (nil_record = records.empty?)
            when :has_one, :belongs_to
              next if assoc_type != :one_to_one
              records = @record.send(model_assoc)
              records = @record.class.new.send('build_'+model_assoc.to_s) if (nil_record = records.nil?)
            end

            yield(association, records, assoc_includes.is_a?(Hash) ? assoc_includes[association] : {}, nil_record)
          end

          @options[:include] = includes if includes
        end

        def headerize(attribute_name)
          str = attribute_name.gsub(/_/, " ").gsub(/\b('?[a-z])/) { $1.capitalize }

          words = str.split(' ')
          str = words[0..-2].join(' ') if words[-2] == words[-1]
          str
        end

    end

  end
end
