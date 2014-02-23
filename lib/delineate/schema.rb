module Delineate
  module Schema
    extend ActiveSupport::Concern

    # Returns a schema hash according to the attribute map. This information
    # could be used to generate clients.
    #
    # The schema hash has two keys: +attributes+ and +associations+. The content
    # for each varies depending on the +access+ parameter which can take values
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
    # that method in your models if you want to customize the schema output.
    #
    def schema(access = nil, schema_classes = [])
      schema_classes.push(@klass_name)
      resolve

      attrs = schema_attributes(access)
      associations = schema_associations(access, schema_classes)

      schema_classes.pop
      {:attributes => attrs, :associations => associations}
    end

    private

      def schema_attributes(access)
        columns = (klass_cti_subclass? ? klass.cti_base_class.columns_hash : {}).merge klass.columns_hash

        returning({}) do |attrs|
          @attributes.each do |attr, opts|
            attr_type = (column = columns[model_attribute(attr).to_s]) ? column.type : nil
            if (access == :read && opts[:access] != :w) or (access == :write && opts[:access] != :ro)
              attrs[attr] = attr_type
            elsif access.nil?
              attrs[attr] = {:type => attr_type, :access => opts[:access] || :rw}
            end
          end
        end
      end

      def schema_associations(access, schema_classes)
        returning({}) do |associations|
          @associations.each do |assoc_name, assoc|
            include_assoc = (access == :read && assoc[:options][:access] != :w) || (access == :write && assoc[:options][:access] != :ro) || access.nil?
            next unless include_assoc

            associations[assoc_name] = {}
            associations[assoc_name][:optional] = true if assoc[:options][:optional]
            associations[assoc_name][:access] = (assoc[:options][:access] || :rw) if access.nil?

            if assoc[:attr_map] && assoc[:attr_map] != assoc[:klass_name].to_s.constantize.attribute_map(@name)
              associations[assoc_name].merge!(assoc[:attr_map].schema(access, schema_classes)) unless schema_classes.include?(assoc[:klass_name])
            end
          end
        end
      end

  end
end
