require_dependency "mindleaps_analytics/application_controller"

module MindleapsAnalytics
  class FindController < ApplicationController

    def update_chapters
      if params[:organization_id] and not params[:organization_id] == '' and not params[:organization_id] == 'All'
        chapters = Chapter.where(organization_id: params[:organization_id])
      else
        chapters = Chapter.all
      end
      respond_to do |format|
        format.json { render :json => chapters }
      end
    end

    def update_groups
      if params[:chapter_id] and not params[:chapter_id] == '' and not params[:chapter_id] == 'All'
        groups = Group.where(chapter_id: params[:chapter_id])
      elsif params[:organization_id] and not params[:organization_id] == '' and not params[:organization_id] == 'All'
        groups = Group.includes(:chapter).where(chapters: {organization_id: params[:organization_id]})
      else
        groups = Group.all
      end
      respond_to do |format|
        format.json { render :json => groups }
      end
    end

    def update_students
      if params[:group_id] and not params[:group_id] == '' and not params[:group_id] == 'All'
        students = Student.where(group_id: params[:group_id]).order(:last_name, :first_name)
      elsif params[:chapter_id] and not params[:chapter_id] == '' and not params[:chapter_id] == 'All'
        students = Student.includes(:group).where(groups: {chapter_id: params[:chapter_id]}).order(:last_name, :first_name)
      elsif params[:organization_id] and not params[:organization_id] == '' and not params[:organization_id] == 'All'
        students = Student.includes(group: {chapter: :organization}).where(chapters: {organization_id: params[:organization_id]}).order(:last_name, :first_name)
      else
        students = Student.all.order(:last_name, :first_name)
      end
      respond_to do |format|
        format.json { render :json => students }
      end
    end

    def update_subjects
      if params[:organization_id] and not params[:organization_id] == '' and not params[:organization_id] == 'All'
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
