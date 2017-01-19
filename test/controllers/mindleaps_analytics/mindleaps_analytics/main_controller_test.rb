require 'test_helper'

module MindleapsAnalytics
  class MindleapsAnalytics::MainControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test "should get first" do
      get mindleaps_analytics_main_first_url
      assert_response :success
    end

    test "should get second" do
      get mindleaps_analytics_main_second_url
      assert_response :success
    end

    test "should get third" do
      get mindleaps_analytics_main_third_url
      assert_response :success
    end

  end
end
