require_dependency "mindleaps_analytics/application_controller"

module MindleapsAnalytics
  class FindController < ApplicationController

    def update_chapters
      if params[:organization_id] and not params[:organization_id] = ''
        chapters = Chapter.where(organization_id: params[:organization_id])
      else
        chapters = Chapter.all
      end
      respond_to do |format|
        format.json { render :json => chapters }
      end
    end

    def update_groups
      if params[:chapter_id] and not params[:chapter_id] = ''
        groups = Group.where("chapter_id = ?", params[:chapter_id])
      elsif params[:organization_id] and not params[:organization_id] = ''
        groups = Group.includes(:chapters).where(chapter: {organization_id: :organization_id})
      else
        groups = Group.all
      end
      respond_to do |format|
        format.json { render :json => groups }
      end
    end

    # def update_students
    #   if params[:group_id] and not params[:group_id] = ''
    #     students = Student.where("group_id = ?", params[:group_id])
    #   else
    #     students = Student.all
    #   end
    #   respond_to do |format|
    #     format.json { render :json => students }
    #   end
    # end

    def update_subjects
      if params[:organization_id] and not params[:organization_id] = ''
        subjects = Subject.where(organization_id: params[:organization_id])
      else
        subjects = Subject.all
      end
      respond_to do |format|
        format.json { render :json => subjects }
      end
    end

  end
end
