class Object
  # I like +returning+ in some contexts, despite what ActiveSupport 3+ thinks :)
  def returning(value)
    yield(value)
    value
  end

  def is_not_a?(klass)
    !self.is_a?(klass)
  end
end

class Hash
  # Renames the specified key to the new value
  def rename_key!(old_key, new_key)
    self[new_key] = self.delete(old_key)
  end
end
