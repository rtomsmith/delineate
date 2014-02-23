module Delineate
  module Serialization
    extend ActiveSupport::Concern

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

    # Given the specified api attributes hash, translates the attribute names to
    # the corresponding model attribute names. Recursive translation on associations
    # is performed. API attributes that are defined as read-only are removed.
    #
    # Input can be a single hash or an array of hashes.
    def map_attributes_for_write(attrs, options = nil)
      raise "Cannot process map #{@klass_name}:#{@name} for write because it has not been resolved" if !resolve

      (attrs.is_a?(Array) ? attrs : [attrs]).each do |attr_hash|
        raise ArgumentError, "Expected attributes hash but received #{attr_hash.inspect}" if attr_hash.is_not_a?(Hash)

        attr_hash.dup.symbolize_keys.each do |k, v|
          if (assoc = @associations[k])
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

    private

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

      # The Rails params hash generated from XML/JSON needs to be translated to a form
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
      # which is incompatible with ActiveRecord nested attributes. So this method
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
