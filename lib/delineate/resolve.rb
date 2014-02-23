module Delineate
  module Resolve
    extend ActiveSupport::Concern

    # Returns true if this map is fully resolved
    def resolved?
      @resolved
    end

    # Attempts to resolve this map and the maps it depends on, including declared associations.
    # Will raise an exception if the map cannot be fully resolved.
    def resolve!
      resolve(:must_resolve)
      self
    end

    # Attempts to resolve this map and the maps it depends on, including declared associations,
    # and returns success status as a boolean. If the +must_resolve+ parameter is truthy, raises
    # raise an exception if the map cannot be fully resolved.
    def resolve(must_resolve = false, resolving = [])
      return true if @resolved
      return true if resolving.include?(@klass_name)    # prevent infinite recursion

      resolving.push(@klass_name)

      result = resolve_associations(must_resolve, resolving)
      result = false unless resolve_sti_baseclass(must_resolve, resolving)

      resolving.pop
      @resolved = result
    end

    private

      # Resolves association maps, and handles map merges as necessary
      def resolve_associations(must_resolve, resolving)
        result = true

        @associations.each do |assoc_name, assoc|
          detect_circular_merge!(assoc_name, assoc)

          assoc_map = assoc[:attr_map] || assoc[:klass_name].constantize.attribute_maps.try(:fetch, @name, nil)
          if assoc_map && assoc_map.resolve(must_resolve, resolving)
            assoc_map = merge_assoc_map(assoc, assoc_map) if merge_option?(assoc[:options])
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

        if merge_option?(@options) && klass_sti_subclass? && !@sti_baseclass_merged
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

      # Raises exception if an association specifies a merge, and the association class's
      # attribute map attempts to merge the association parent attribute map.
      def detect_circular_merge!(assoc_name, assoc)
        return if assoc.nil? || assoc[:attr_map].nil? || !merge_option?(assoc[:options])
        return unless (map = assoc[:klass_name].constantize.attribute_maps.try(:fetch, @name, nil))

        map.associations.each_value do |a|
          if a[:klass_name] == @klass_name && merge_option?(a[:options]) && a[:attr_map]
            raise "Detected attribute map circular merge references: class=#{@klass_name}, association=#{assoc_name}"
          end
        end
      end

      def merge_assoc_map(assoc, assoc_map)
        if merge_option?(assoc[:options]) && assoc[:attr_map]
          merge_map = assoc[:klass_name].constantize.attribute_maps[@name]
          assoc_map = merge_map.dup.merge!(assoc_map, :with_options => true, :with_state => true)
        end
        assoc_map
      end

  end
end
