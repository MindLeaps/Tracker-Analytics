require_dependency "mindleaps_analytics/application_controller"

module MindleapsAnalytics
  class FindController < ApplicationController

    def update_students
      students = Student.where("group_id = ?", params[:group_id])
      respond_to do |format|
        format.json { render :json => students }
      end
    end

  end
end
