require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'active_support/json.rb'
require 'active_support/xml_mini.rb'

describe "Attribute Map declaration (attributes)" do
  it "should require a map name" do
    running {
      Post.map_attributes do
        attribute :post_id, :using => :id
      end
    }.should raise_error(ArgumentError)
  end

  it "should allow all valid attribute options" do
    running {
      Post.map_attributes :test do
        attribute :name, :using => :attr, :access => :rw, :optional => true, :read => lambda{}, :write => lambda{}
      end
    }.should_not raise_error
  end

  it "should raise an error for invalid attribute options" do
    running {
      Post.map_attributes :test do
        attribute :name, :hello => true
      end
    }.should raise_error(ArgumentError)
  end

  it "should raise an error for unknown attribute" do
      Post.map_attributes :test do
        attribute :xxx, :access => :ro
      end

      p = Post.new
      expect {p.test_attributes}.to raise_error(NoMethodError)
  end

  it "should error for writeable attribute not declared as attribute_accessible" do
    running {
      Post.map_attributes :test do
        attribute :xxx
      end
    }.should raise_error(RuntimeError, /Expected 'attr_accessible :xxx'/)
  end

  it "should allow all valid access options" do
    running {
      Post.attr_accessible(:created_at)
      Post.map_attributes :test do
        attribute :title, :access => :ro
        attribute :content, :access => :rw
        attribute :created_at, :access => :w
      end
    }.should_not raise_error
  end

  it "should not allow :write option when access is :ro" do
    running {
      Post.map_attributes :test do
        attribute :name, :access => :ro, :write => lambda{}
      end
    }.should raise_error(ArgumentError)
  end

  it "should raise an error for invalid access option value" do
    running {
      Post.map_attributes :test do
        attribute :name, :access => :ddd
      end
    }.should raise_error(ArgumentError)
  end

  it "should automatically name an attribute read/write lamda" do
    Post.map_attributes :test do
      attribute :summary, :read => lambda {|p| p.instance_variable_get(:@test)},
                        :write => lambda {|p, v| p.instance_variable_set(:@test, v)}
    end

    p = Post.new
    p.summary_test = "This is a test"
    p.summary_test.should == "This is a test"
    expect(p.test_attributes).to include(:summary => 'This is a test')
  end

  it "should honor the model_attr name for an attribute read/write lamda" do
    Post.map_attributes :test do
      attribute :name, :using => :test_name, :access => :ro, :read => lambda{|p| "This is a test"}
    end
    p = Post.new
    p.test_name.should == "This is a test"
  end

end

describe "Attribute Map declaration (associations)" do
  before(:all) do
    reload_model_classes!
  end

  it "should raise an error for an undefined association" do
    running {
      Post.map_attributes :test do
        association :hello
      end
    }.should raise_error(ArgumentError)
  end

  it "should raise an error for invalid association options" do
    running {
      Post.map_attributes :test do
        association :comments, :hello => true
      end
    }.should raise_error(ArgumentError)
  end

  it "should allow all valid association options" do
    running {
      Post.attr_accessible(:name)
      Post.map_attributes :test do
        attribute :name
        association :comments, :using => :comments, :override => :merge, :polymorphic => false, :access => :rw,
                    :optional => true
      end
    }.should_not raise_error
  end

  it "should raise an error for invalid access option value" do
    running {
      Post.map_attributes :test do
        association :comments, :access => :bad
      end
    }.should raise_error(ArgumentError)
  end

  it "should raise an error for invalid :override option value" do
    running {
      Reply.map_attributes :test, :override => true do
        association :comments
      end
    }.should raise_error(ArgumentError)
  end

  it "should allow :override for STI subclass" do
    running {
      Reply.map_attributes :test, :override => :replace do
        attribute :type
      end
    }.should_not raise_error
  end

  it "should disallow :override for non-STI subclass" do
    running {
      Comment.map_attributes :test, :override => :replace do
        attribute :type
      end
    }.should raise_error(ArgumentError)
  end

  it "should raise an error for :replace with no specs" do
    running {
      Post.map_attributes :test do
        association :comments, :override => :replace do
        end
      end
    }.should raise_error(ArgumentError)
  end

  it "should not allow circular merge references" do
    running {
      Comment.map_attributes :test do
        attribute   :content
        association :post, :optional => true do
          attribute :content
        end
      end

      Post.map_attributes :test do
        attribute   :title
        association :comments do
          attribute :commentor, :access => :ro
        end
      end
    }.should_not raise_error

    running {Post.attribute_map(:test).send('resolve!')}.should raise_error(RuntimeError, /circular merge/)
  end

  it "should allow circular non-merge references" do
    running {
      Comment.map_attributes :test do
        attribute   :content
        association :post, :access => :ro, :optional => true, :override => :replace do
          attribute :title
          attribute :content
        end
      end

      Post.map_attributes :test do
        attribute   :title
        association :comments do
          attribute :commentor, :access => :ro
        end
      end
    }.should_not raise_error

    running {Post.attribute_map(:test).send('resolve!')}.should_not raise_error



    c = Comment.new(:content => "This is the content", :commentor => 'John Q Public')
    p = Post.new(:title => 'This is the title')
    c.post = p
    p.comments = [c]

    expected_result = {:title=>"This is the title",
                       :comments=>[{:content=>"This is the content", :commentor=>"John Q Public", :post=>{:title=>"This is the title", :content=>nil}}]
                      }
    expect(p.test_attributes(:include => {:comments => {:include => :post}})).to eq(expected_result)
  end

  it "should process replacing association's map" do
    running {
      Comment.attr_accessible(:test)
      Comment.map_attributes :test do
        attribute   :content
        attribute   :commentor
        association :post, :optional => true
      end

      Post.map_attributes :test do
        association :comments, :override => :replace do
          attribute :test
          attribute :commentor, :access => :ro
        end
      end
    }.should_not raise_error
    Post.attribute_map(:test).send('resolve!')

    Post.attribute_map(:test).associations[:comments][:attr_map].should_not be_nil
    Post.attribute_map(:test).associations[:comments][:attr_map].associations.has_key?(:post).should be_false
    Post.attribute_map(:test).associations[:comments][:attr_map].attributes.should have_key(:test)
    Post.attribute_map(:test).associations[:comments][:attr_map].attributes.should_not have_key(:content)
    Post.attribute_map(:test).associations[:comments][:attr_map].attributes.should have_key(:commentor)
    Post.attribute_map(:test).associations[:comments][:attr_map].attributes[:commentor][:access].should == :ro
  end

  it "should process merging association's map" do
    running {
      Comment.attr_accessible(:test)
      Comment.map_attributes :test do
        attribute   :content
        attribute   :commentor, :access => :ro
        association :post, :optional => true
      end

      Post.map_attributes :test do
        association :comments, :override => :merge do
          attribute :test
          attribute :commentor
        end
      end
    }.should_not raise_error
    Post.attribute_map(:test).send('resolve!')

    Post.attribute_map(:test).associations[:comments][:attr_map].should_not be_nil
    Post.attribute_map(:test).associations[:comments][:attr_map].associations.size.should == 1
    Post.attribute_map(:test).associations[:comments][:attr_map].attributes.should have_key(:test)
    Post.attribute_map(:test).associations[:comments][:attr_map].attributes.should have_key(:content)
    Post.attribute_map(:test).associations[:comments][:attr_map].attributes.should have_key(:commentor)
    Post.attribute_map(:test).associations[:comments][:attr_map].attributes[:commentor][:access].should_not == :ro
    Post.attribute_map(:test).associations[:comments][:attr_map].associations.should have_key(:post)
  end

  it "should use STI base class map in a subclass" do
    running {
      Post.map_attributes :test do
        attribute :title
      end
      Comment.map_attributes :test do
        attribute   :content
        attribute   :commentor, :access => :ro
        association :post, :optional => true
      end
      Reply.map_attributes :test do
        attribute :type
      end
    }.should_not raise_error
    Reply.attribute_map(:test).send('resolve!')

    Reply.attribute_map(:test).associations[:post].should_not be_nil
    Reply.attribute_map(:test).attributes.should have_key(:type)
    Reply.attribute_map(:test).attributes.should have_key(:content)
    Reply.attribute_map(:test).attributes.should have_key(:commentor)
  end

  it "should override STI base class map in a subclass when specified" do
    running {
      Comment.map_attributes :test do
        attribute   :content
        attribute   :commentor, :access => :ro
        association :post, :optional => true
      end

      Reply.map_attributes :test, :override => :replace do
        attribute :type
      end
    }.should_not raise_error
    Reply.attribute_map(:test).send('resolve!')

    Reply.attribute_map(:test).associations[:post].should be_nil
    Reply.attribute_map(:test).attributes.should have_key(:type)
    Reply.attribute_map(:test).attributes.should_not have_key(:content)
    Reply.attribute_map(:test).attributes.should_not have_key(:commentor)
  end

end

describe "AttributeMap Serializer" do
  it "should retrieve attributes as a hash (omitting optional)" do
    p = Post.first
    attrs = p.api_attributes

    attrs.keys.should == [:id, :title, :content, :created_at, :author, :topics]
    attrs[:content].should == "This is the content for post 1"
    attrs[:author].keys.should == [:id, :first_name, :last_name, :name, :email]
    attrs[:author][:name].should == 'Tom Smith'
    attrs[:author].should_not have_key(:posts)
    attrs[:topics].should have(2).items
  end

  it "should retrieve attributes as json" do
    p = Post.first
    attrs = p.mapped_attributes(:api, :json)
    attrs.should be_a_kind_of(String)
    attrs = ActiveSupport::JSON.decode(attrs).symbolize_keys

    (attrs.keys - [:id, :title, :content, :created_at, :author, :topics]).should be_empty
    ([:id, :title, :content, :created_at, :author, :topics] - attrs.keys).should be_empty
    attrs[:content].should == "This is the content for post 1"
    attrs[:author].symbolize_keys!
    (attrs[:author].keys - [:id, :first_name, :last_name, :name, :email]).should be_empty
    ([:id, :first_name, :last_name, :name, :email] - attrs[:author].keys).should be_empty
    attrs[:author][:name].should == 'Tom Smith'
    attrs[:author].should_not have_key(:posts)
    attrs[:topics].should have(2).items
  end

  it "should retrieve attributes as xml" do
    p = Post.first
    attrs = p.mapped_attributes(:api, :xml, :root => 'response', :dasherize => false)
    attrs.should be_a_kind_of(String)
    attrs = Hash.from_xml(attrs)['response'].symbolize_keys

    (attrs.keys - [:id, :title, :content, :created_at, :author, :topics]).should be_empty
    ([:id, :title, :content, :created_at, :author, :topics] - attrs.keys).should be_empty
    attrs[:content].should == "This is the content for post 1"
    attrs[:author].symbolize_keys!
    (attrs[:author].keys - [:id, :first_name, :last_name, :name, :email]).should be_empty
    ([:id, :first_name, :last_name, :name, :email] - attrs[:author].keys).should be_empty
    attrs[:author][:name].should == 'Tom Smith'
    attrs[:author].should_not have_key(:posts)
    attrs[:topics].should have(2).items
  end

  it "should raise an error if a specified association does not have a corresponding map" do
    reload_model_classes!

    Post.map_attributes :test do
      association :comments
    end
    running {
      Post.first.test_attributes
    }.should raise_error(RuntimeError, /Cannot resolve map/)
  end

  it "should honor the :only option" do
    p = Post.first

    attrs = p.api_attributes(:only => :id)
    attrs.keys.should == [:id]

    attrs = p.api_attributes(:only => [:id, :author])
    attrs.keys.should == [:id, :author]
    attrs[:author].keys.should == [:id, :first_name, :last_name, :name, :email]
  end

  it "should honor the :except option" do
    p = Post.first
    attrs = p.api_attributes(:except => :id)

    attrs.keys.should == [:title, :content, :created_at, :author, :topics]
    attrs[:author].keys.should == [:id, :first_name, :last_name, :name, :email]

    attrs = p.api_attributes(:except => [:id, :title])
    attrs.keys.should == [:content, :created_at, :author, :topics]
    attrs[:author].keys.should == [:id, :first_name, :last_name, :name, :email]
  end

  it "should let :only take precendence over :except" do
    p = Post.first
    attrs = p.api_attributes(:only => [:id, :title], :except => :title)

    attrs.keys.should == [:id, :title]
  end

  it "should let :include specify optional attributes" do
    p = Post.first

    attrs = p.api_attributes(:include => :heavy_attr)
    attrs.keys.should == [:id, :title, :content, :created_at, :heavy_attr, :author, :topics]
  end

  it "should allow specifying an unknown :include" do
    p = Post.first

    attrs = p.api_attributes(:include => :unknown)
    attrs.keys.should == [:id, :title, :content, :created_at, :author, :topics]
  end

  it "should let :include specify optional attribute groups" do
    p = Post.first

    attrs = p.api_attributes(:include => :extended_attrs)
    attrs.keys.should == [:id, :title, :content, :created_at, :heavy_attr, :author, :topics]
  end

  it "should use :include option to retrieve optional associations" do
    a = Author.first

    attrs = a.api_attributes
    attrs.should_not have_key(:posts)
    attrs.should_not have_key(:author_group)

    attrs = a.api_attributes(:include => :author_group)
    attrs.should_not have_key(:posts)
    attrs.should have_key(:author_group)

    p = Post.first
    attrs = p.api_attributes(:include => {:author => {:include => :posts}})
    attrs[:author].should have_key(:posts)
    attrs[:author][:posts].size.should == 3
  end

  it "should serialize a polymorphic one-one association" do
    attrs = Author.find(5).api_attributes
    attrs[:email][:special_email].should == 'special'
    attrs[:email][:email].should == "author5@email.com"
  end

  it "should serialize a polymorphic collection" do
    attrs = Post.first.api_attributes(:include => :comments)

    attrs[:comments].should have(3).items
    attrs[:comments][0].should_not have_key(:type)
    attrs[:comments][1].should_not have_key(:type)
    attrs[:comments].last[:type].should == 'Reply'
  end

  it "must allow including both optional attributes and associations with mixed arrays and hashes" do
    p = Post.first
    includes = {:include => [:extended_attrs, {:author => {:include => [:posts, :author_group]}}, :comments]}
    attrs = p.api_attributes(includes)

    attrs.keys.should == [:id, :title, :content, :created_at, :heavy_attr, :author, :topics, :comments]
    attrs[:author].should have_key(:posts)
    attrs[:author].should have_key(:author_group)
    attrs[:comments].should have(3).items
  end

  it "should process includes specified in a hash" do
    p = Post.first
    includes = {:include => {:author => {:include => [:posts, :author_group]}, :comments => {}}}
    attrs = p.api_attributes(includes)

    attrs.keys.should == [:id, :title, :content, :created_at, :author, :topics, :comments]
    attrs[:author].should have_key(:posts)
    attrs[:author].should have_key(:author_group)
    attrs[:comments].should have(3).items
  end
end


describe "AttributeMap Deerializer" do
  it "handles inputting attributes from a hash for new objects" do
    h = {:title => "New title", :content => "New content"}

    p = Post.new
    p.api_attributes = h
    p.attributes.should == {"id" => nil, "title"=>"New title", "content"=>"New content", "author_id"=>nil, "created_at"=>nil}
  end

  it "handles inputting attributes from a hash for existing objects" do
    h = {:title => "New title", :content => "New content"}

    p = Post.first
    p.api_attributes = h
    p.title.should == 'New title'
    p.content.should == 'New content'
    p.author_id.should_not be_nil
    p.created_at.should_not be_nil
  end

  it "allows unrecognized and unspecified attributes but not set their values" do
    h = {:title => "New title", :content => "New content", :author_id => 1, :unknown => 'sdfsdf'}

    p = Post.new
    p.api_attributes = h

    p.attributes.should == {"id" => nil, "created_at"=>nil, "title"=>"New title", "content"=>"New content", "author_id"=>nil}
    p[:unknown].should be_nil
  end

  it "does not overwrite read-only attributes" do
    h = {:created_at => nil}

    p = Post.first
    p.api_attributes = h
    p.changed?.should be_false
    p.created_at.should_not be_nil
  end

  it "should let you specify an external name that is different from internal name" do
    Post.map_attributes :test do
      attribute :public_title, :model_attr => :title
    end

    p = Post.first
    p.test_attributes = {:public_title => 'New title'}
    p.title.should == 'New title'
  end

  it "should handle updating a one-to-one association attributes" do
    h = {:author => {:id => 1, :first_name => 'New', :email => {:email => 'new_email'}}}

    p = Post.first
    p.api_attributes = h

    p.author_id.should == 1
    p.created_at.should_not be_nil
    p.author.changed?.should be_true
    p.author.first_name.should == 'New'
    p.author.last_name.should == 'Smith'
    p.author.email.email_addr.should == 'new_email'
  end

  it "must not overwrite read-only associations" do
    Post.map_attributes :test do
      association :author, :access => :ro
    end
    Author.map_attributes :test do
      attribute :first_name
      attribute :last_name
    end

    p = Post.first
    p.test_attributes = {:author => {:first_name => 'New'}}
    p.author.changed?.should be_false
    p.author.first_name.should_not == 'New'
  end

  it "lets you specify an association external name that different that the internal name" do
    Post.accepts_nested_attributes_for(:author, :update_only => true)
    Post.map_attributes :test do
      association :public_author, :using => :author
    end
    Author.map_attributes :test do
      attribute :first_name
      attribute :last_name
    end

    p = Post.first
    p.test_attributes = {:public_author => {:first_name => 'New'}}

    p.author_id.should == 1
    p.author.changed?.should be_true
    p.author.first_name.should == 'New'
  end

  it "sets STI base class attributes and associations when writing to subclass" do
    r = Reply.new
    r.api_attributes = {:content => 'Content for test', :post => {:title => 'STI Title'}}

    r.content.should == 'Content for test'
    r.post.id.should == nil
    r.post.title.should == 'STI Title'
    r.type.should == 'Reply'
  end

  it "should delete a one-one association item" do
    h = {:email => {:id => 4, :_destroy => true}}

    a = Author.find(4)
    a.api_attributes = h

    a.email.should be_marked_for_destruction
  end

  it "should add an item to a one-many association" do
    h = {:comments => [{:commentor => 'A Commentor', :content => 'Some new comment'}]}

    p = Post.first
    p.api_attributes = h

    p.comments.should have(4).items
    p.comments.last.new_record?.should be_true
  end

  it "should update an item to a one-many association" do
    h = {:comments => [{:id => 1, :commentor => 'A Commentor'}]}

    p = Post.first
    p.api_attributes = h

    p.comments.should have(3).items
    p.comments.first.new_record?.should be_false
    p.comments.first.should be_changed
    p.comments.first.commentor.should == 'A Commentor'
    p.comments.first.content.should == 'Comment 1 for post 1'
  end

  it "should delete an item from a one-many association" do
    h = {:comments => [{:id => 1, :_destroy => true}]}

    p = Post.first
    p.api_attributes = h

    p.comments.should have(3).items
    p.comments.first.should be_marked_for_destruction
  end

  it "should not allow delete if the association map spec doesn't allow it" do
    Comment.map_attributes :test do
      attribute :content
    end
    Post.has_many :comments_no_delete, :class_name => 'Comment'
    Post.accepts_nested_attributes_for(:comments_no_delete, :allow_destroy => false)
    Post.attr_accessible(:comments_no_delete_attributes)
    Post.map_attributes :test do
      attribute :title
      association :comments_no_delete
    end

    h = {:comments => [{:id => 1, :_destroy => true}]}

    p = Post.first
    p.test_attributes = h

    p.comments.should have(3).items
    p.comments.first.should_not be_marked_for_destruction
  end

  it "should serialize a polymorphic collection" do
    attrs = Post.first.api_attributes(:include => :comments)

    attrs[:comments].should have(3).items
    attrs[:comments][0].should_not have_key(:type)
    attrs[:comments][1].should_not have_key(:type)
    attrs[:comments].last[:type].should == 'Reply'
  end

end
