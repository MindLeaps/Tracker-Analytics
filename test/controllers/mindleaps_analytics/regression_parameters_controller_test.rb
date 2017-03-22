require 'test_helper'

module MindleapsAnalytics
  class RegressionParametersControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @regression_parameter = mindleaps_analytics_regression_parameters(:one)
    end

    test "should get index" do
      get regression_parameters_url
      assert_response :success
    end

    test "should get new" do
      get new_regression_parameter_url
      assert_response :success
    end

    test "should create regression_parameter" do
      assert_difference('RegressionParameter.count') do
        post regression_parameters_url, params: { regression_parameter: { name: @regression_parameter.name, value: @regression_parameter.value } }
      end

      assert_redirected_to regression_parameter_url(RegressionParameter.last)
    end

    test "should show regression_parameter" do
      get regression_parameter_url(@regression_parameter)
      assert_response :success
    end

    test "should get edit" do
      get edit_regression_parameter_url(@regression_parameter)
      assert_response :success
    end

    test "should update regression_parameter" do
      patch regression_parameter_url(@regression_parameter), params: { regression_parameter: { name: @regression_parameter.name, value: @regression_parameter.value } }
      assert_redirected_to regression_parameter_url(@regression_parameter)
    end

    test "should destroy regression_parameter" do
      assert_difference('RegressionParameter.count', -1) do
        delete regression_parameter_url(@regression_parameter)
      end

      assert_redirected_to regression_parameters_url
    end
  end
end
