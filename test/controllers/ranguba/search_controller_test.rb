require "test_helper"

class Ranguba::SearchControllerTest < ActionDispatch::IntegrationTest
  def setup
    setup_database
  end

  def teardown
    teardown_database
  end

  def test_routes
    base = { :controller => "ranguba/search", :action => "index" }
    assert_recognizes(base.merge(:search_request => "query/q"),
                      "/search/query/q")
    assert_recognizes(base.merge(:search_request => "query/q/type/t"),
                      "/search/query/q/type/t")
    assert_recognizes(base.merge(:search_request => "query/q/type/t/category/c"),
                      "/search/query/q/type/t/category/c")
    assert_recognizes(base.merge(:search_request => "type/t/category/c/query/q"),
                      "/search/type/t/category/c/query/q")
  end

  def test_index
    get search_url
    assert_response :success
    assert_template "search/index"
  end

  def test_request_hash
    get search_url(search_request: "type/t"),
        params: {
          query: "q",
          page: 2,
        }
    assert_redirected_to(search_path(:search_request => "type/t/query/q"))
  end

  def test_request_hash_form
    get search_url(search_request: "type/t"),
        params: {
          query: "q",
        }
    assert_redirected_to(search_path(search_request: "type/t/query/q"))
  end

  def test_request_string
    get search_url(search_request: "query/q/type/t")
    assert_response :success
    assert_template "search/index"
  end

  def test_unknown_parameter
    get search_url(search_request: "query/q/unknown/value")
    assert_response 400
    assert_template "search/bad_request"
  end

  def test_too_large_page
    get search_url(search_request: "query/q",
                   page: 2)
    assert_response 404
    assert_template "search/not_found"
  end

  def test_too_small_page
    get search_url(search_request: "query/q",
                   page: 0)
    assert_response 404
    assert_template "search/not_found"
  end

  def test_too_small_negative
    get search_url(search_request: "query/q",
                   page: -1)
    assert_response 404
    assert_template "search/not_found"
  end
end
