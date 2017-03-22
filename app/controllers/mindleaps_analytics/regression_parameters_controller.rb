require_dependency "mindleaps_analytics/application_controller"

module MindleapsAnalytics
  class RegressionParametersController < ApplicationController
    before_action :set_regression_parameter, only: [:show, :edit, :update, :destroy]

    # GET /regression_parameters
    def index
      @regression_parameters = RegressionParameter.all
    end

    # GET /regression_parameters/1
    def show
    end

    # GET /regression_parameters/new
    def new
      @regression_parameter = RegressionParameter.new
    end

    # GET /regression_parameters/1/edit
    def edit
    end

    # POST /regression_parameters
    def create
      @regression_parameter = RegressionParameter.new(regression_parameter_params)

      if @regression_parameter.save
        redirect_to @regression_parameter, notice: 'Regression parameter was successfully created.'
      else
        render :new
      end
    end

    # PATCH/PUT /regression_parameters/1
    def update
      if @regression_parameter.update(regression_parameter_params)
        redirect_to @regression_parameter, notice: 'Regression parameter was successfully updated.'
      else
        render :edit
      end
    end

    # DELETE /regression_parameters/1
    def destroy
      @regression_parameter.destroy
      redirect_to regression_parameters_url, notice: 'Regression parameter was successfully destroyed.'
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_regression_parameter
        @regression_parameter = RegressionParameter.find(params[:id])
      end

      # Only allow a trusted parameter "white list" through.
      def regression_parameter_params
        params.require(:regression_parameter).permit(:name, :value)
      end
  end
end
