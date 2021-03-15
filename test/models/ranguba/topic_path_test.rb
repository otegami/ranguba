require 'test_helper'

class Ranguba::TopicPathTest < ActiveSupport::TestCase

  def setup
  end

  def test_search_request
    items = []
    items << Ranguba::TopicPathItem.new(:type, 'html')
    items << Ranguba::TopicPathItem.new(:category, 'blog')
    items << Ranguba::TopicPathItem.new(:query, 'q1')
    items << Ranguba::TopicPathItem.new(:query, 'q2')
    items << Ranguba::TopicPathItem.new(:query, 'q3')
    topic_path = Ranguba::TopicPath.new(*items)
    assert_equal('type/html/category/blog/query/q1+q2+q3', topic_path.search_request)
    topic_path = topic_path[0..3]
    assert_equal('type/html/category/blog/query/q1+q2', topic_path.search_request)
    topic_path = topic_path[0..2]
    assert_equal('type/html/category/blog/query/q1', topic_path.search_request)
    topic_path = topic_path[0..1]
    assert_equal('type/html/category/blog', topic_path.search_request)
    topic_path = topic_path[0..0]
    assert_equal('type/html', topic_path.search_request)
  end

  def test_search_request__empty_items
    topic_path = Ranguba::TopicPath.new
    assert_nil(topic_path.search_request)
  end
end
