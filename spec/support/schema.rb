# Support for creating the test schema and seed data

def create_schema!
  ActiveRecord::Schema.define :version => 0 do
    create_table "posts", :force => true do |t|
      t.string      :title
      t.text        :content
      t.references  :author, :null => :false
      t.datetime    :created_at
    end

    create_table "authors", :force => true do |t|
      t.string    :first_name
      t.string    :last_name
      t.references :author_group
    end

    create_table "comments", :force => true do |t|
      t.string      :commentor
      t.references  :post
      t.text        :content
      t.string      :type
      t.datetime    :created_at
    end

    create_table "topics", :force => true do |t|
      t.string :name
    end

    create_table "post_topics", :force => true do |t|
      t.references :topic
      t.references :post
    end

    create_table "author_groups", :force => true do |t|
      t.string  :name
    end

    create_table "emails", :force => true do |t|
      t.string      :email_addr
      t.references  :author
      t.string      :type
    end

  end
end

def clean_database!
  seed_author_groups
  seed_authors
  seed_emails
  seed_topics
  seed_posts
  seed_post_topics
  seed_comments
end

def seed_author_groups
  ActiveRecord::Base.connection.execute "DELETE FROM author_groups"
  AuthorGroup.create!(:name => 'Admin')   # 1
  AuthorGroup.create!(:name => 'Staff')   # 2
  AuthorGroup.create!(:name => 'Guest')   # 3
end

def seed_authors
  ActiveRecord::Base.connection.execute "DELETE FROM authors"
  Author.create!(:first_name => 'Tom', :last_name => 'Smith', :author_group => AuthorGroup.find_by_name('Admin'))
  Author.create!(:first_name => 'John', :last_name => 'Staffer', :author_group => AuthorGroup.find_by_name('Staff'))
  Author.create!(:first_name => 'John', :last_name => 'Smith', :author_group => AuthorGroup.find_by_name('Staff'))
  Author.create!(:first_name => 'John', :last_name => 'Public', :author_group => AuthorGroup.find_by_name('Guest'))
  Author.create!(:first_name => 'Mary', :last_name => 'Jones', :author_group => AuthorGroup.find_by_name('Staff'))
  Author.create!(:first_name => 'Julie', :last_name => 'Smith', :author_group => AuthorGroup.find_by_name('Guest'))
end

def seed_emails
  Email.create!(:author_id => 1, :email_addr => 'author1@email.com')
  Email.create!(:author_id => 2, :email_addr => 'author2@email.com')
  Email.create!(:author_id => 3, :email_addr => 'author3@email.com')
  Email.create!(:author_id => 4, :email_addr => 'author4@email.com')
  SpecialEmail.create!(:author_id => 5, :email_addr => 'author5@email.com')
end

def seed_topics
  ActiveRecord::Base.connection.execute "DELETE FROM topics"
  Topic.create!(:name => 'NoSQL')       # 1
  Topic.create!(:name => 'Ruby')        # 2
  Topic.create!(:name => 'Rails')       # 3
  Topic.create!(:name => 'Events')      # 4
  Topic.create!(:name => 'General')     # 5
end

def seed_posts
  Post.create!(:title => "Post Number 1" , :content => "This is the content for post 1" , :author => Author.find(1))
  Post.create!(:title => "Post Number 2" , :content => "This is the content for post 2" , :author => Author.find(2))
  Post.create!(:title => "Post Number 3" , :content => "This is the content for post 3" , :author => Author.find(3))
  Post.create!(:title => "Post Number 4" , :content => "This is the content for post 4" , :author => Author.find(4))
  Post.create!(:title => "Post Number 5" , :content => "This is the content for post 5" , :author => Author.find(5))

  Post.create!(:title => "Post Number 6" , :content => "This is the content for post 6" , :author => Author.find(1))
  Post.create!(:title => "Post Number 7" , :content => "This is the content for post 7" , :author => Author.find(1))
end

def seed_post_topics
  PostTopic.create!(:topic => Topic.find_by_name('NoSQL'), :post_id => 1)
  PostTopic.create!(:topic => Topic.find_by_name('Events'), :post_id => 1)

  PostTopic.create!(:topic => Topic.find_by_name('NoSQL'), :post_id => 2)
  PostTopic.create!(:topic => Topic.find_by_name('Ruby'), :post_id => 3)
  PostTopic.create!(:topic => Topic.find_by_name('Rails'), :post_id => 4)
  PostTopic.create!(:topic => Topic.find_by_name('Events'), :post_id => 5)
  PostTopic.create!(:topic => Topic.find_by_name('General'), :post_id => 6)
  PostTopic.create!(:topic => Topic.find_by_name('Ruby'), :post_id => 7)
  PostTopic.create!(:topic => Topic.find_by_name('Rails'), :post_id => 7)
end

def seed_comments
  Comment.create!(:commentor => 'Anonymous', :post_id => 1, :content => 'Comment 1 for post 1')
  Comment.create!(:commentor => 'commentor1', :post_id => 1, :content => 'Comment 2 for post 1')
  Comment.create!(:commentor => 'commentor2', :post_id => 2, :content => 'Comment 1 for post 2')
  Comment.create!(:commentor => 'commentor3', :post_id => 3, :content => 'Comment 1 for post 3')
  Comment.create!(:commentor => 'commentor7', :post_id => 7, :content => 'Comment 1 for post 7')
  Comment.create!(:commentor => 'commentor8', :post_id => 7, :content => 'Comment 2 for post 7')

  Reply.create!(:commentor => 'commentor1', :post_id => 1, :content => 'Reply to Comment for post 1')
end
