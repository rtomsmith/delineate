# Contains ActiveRecord model test classes

class Post < ActiveRecord::Base
end
class Author < ActiveRecord::Base
end
#class Comment < ActiveRecord::Base
#end
#class Reply < Comment
#end
class Topic < ActiveRecord::Base
end
class AuthorGroup < ActiveRecord::Base
end
class Email < ActiveRecord::Base
end

class PostTopic < ActiveRecord::Base
  belongs_to  :post
  belongs_to  :topic
  has_one     :author, :through => :post
end

class Comment < ActiveRecord::Base
  belongs_to  :post
  accepts_nested_attributes_for :post

  attr_accessible :commentor, :content, :post, :post_attributes, :post_id

  map_attributes :api do
    attribute :id
    attribute :commentor
    attribute :content
    attribute :created_at, :access => :ro

    association :post, :optional => true
  end
end

class Reply < Comment
  attr_accessible :type

  map_attributes :api do
    attribute :type
  end
end

class Post < ActiveRecord::Base
  belongs_to :author
  has_many   :post_topics
  has_many   :topics, :through => :post_topics
  has_many   :comments

  accepts_nested_attributes_for :author, :allow_destroy => true
  accepts_nested_attributes_for :post_topics
  accepts_nested_attributes_for :topics, :allow_destroy => false
  accepts_nested_attributes_for :comments, :allow_destroy => true

  attr_accessible :title, :content, :author, :author_attributes, :post_topics, :post_topics_attributes, :comments, :comments_attributes
  attr_accessible :topics, :topics_attributes

  map_attributes :api do
    attribute :id
    attribute :title
    attribute :content
    attribute :created_at, :access => :ro

    attribute :heavy_attr, :access => :ro, :optional => :extended_attrs

    association :author, :override => :merge do
      attribute :name, :using => :full_name, :access => :ro
    end

    association :topics
    association :comments, :optional => true, :polymorphic => true
  end

  def heavy_attr
    true
  end
end

class Author < ActiveRecord::Base
  belongs_to  :author_group
  has_many    :posts
  has_many    :post_topics, :through => :posts
  has_one     :email

  accepts_nested_attributes_for :author_group
  accepts_nested_attributes_for :posts
  accepts_nested_attributes_for :email, :allow_destroy => true

  attr_accessible :first_name, :last_name, :full_name, :email_attributes, :posts_attributes, :author_group, :author_group_attributes

  scope :by_topic, lambda {|topic_id| joins(:post_topics).where(:topic_id => topic_id)}

  map_attributes :api do
    attribute :id
    attribute :first_name
    attribute :last_name

    association :email, :polymorphic => true
    association :posts, :optional => true, :override => :replace do
      attribute :id
      attribute :title
      attribute :content
      attribute :created_at, :access => :ro
    end
    #association :posts_circular, :using => :posts, :optional => true  # This should generate "circular merge" error when included
    association :author_group, :optional => true
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def topics
    post_topics.map{|pt| pt.topic.name}.uniq
  end
end

class Email < ActiveRecord::Base
  belongs_to  :author

  attr_accessible :email_addr, :author_id

  map_attributes :api do
    attribute :id
    attribute :email, :using => :email_addr
  end
end

class SpecialEmail < Email
  attr_accessible :special_email

  map_attributes :api do
    attribute :special_email
  end

  def special_email
    'special'
  end
end


class Topic < ActiveRecord::Base
  has_many :post_topics
  has_many :posts, :through => :post_topics

  attr_accessible :name

  map_attributes :api do
    attribute :id
    attribute :topic, :using => :name
  end
end

class AuthorGroup < ActiveRecord::Base
  has_many  :authors

  accepts_nested_attributes_for :authors
  attr_accessible :name, :authors_attributes

  map_attributes :api do
    attribute   :id
    attribute   :name
    association :authors, :optional => true
  end
end



# Used to reinitialize class defintions
def reload_model_classes!
  Object.send(:remove_const, :Post)
  Object.send(:remove_const, :Author)
  Object.send(:remove_const, :Reply)
  Object.send(:remove_const, :Comment)
  Object.send(:remove_const, :Topic)
  Object.send(:remove_const, :AuthorGroup)
  Object.send(:remove_const, :PostTopic)

  load __FILE__
end
