require 'test_helper'

module MindleapsAnalytics
  class MainControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test "should get first" do
      get main_first_url
      assert_response :success
    end

    test "should get second" do
      get main_second_url
      assert_response :success
    end

    test "should get third" do
      get main_third_url
      assert_response :success
    end

  end
end
