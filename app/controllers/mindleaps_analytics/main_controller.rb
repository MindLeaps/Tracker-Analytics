require_dependency "mindleaps_analytics/application_controller"
require 'sql/queries'
include SQL

module MindleapsAnalytics
  class MainController < ApplicationController

    def second
      @subject = params[:subject_select]

      @organizations = policy_scope Organization
      if not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @chapters = Chapter.where(organization_id: @selected_organization_id)
      else
        @chapters = policy_scope Chapter
      end

      if not @selected_group_id.nil? and not @selected_group_id == '' and not @selected_group_id == 'All'
        @groups = Group.where(chapter_id: @selected_chapter_id)
      elsif not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @groups = Group.includes(:chapter).where(chapters: {organization_id: @selected_organization_id})
      else
        @groups = policy_scope Group
      end

      if not @selected_group_id.nil? and not @selected_group_id == '' and not @selected_group_id == 'All'
        @students = Student.where(group_id: @selected_group_id).order(:last_name, :first_name).all
      elsif not @selected_chapter_id.nil? and not @selected_chapter_id == '' and not @selected_chapter_id == 'All'
        @students = Student.includes(:group).where(groups: {chapter_id: @selected_chapter_id}).order(:last_name, :first_name).all
      elsif not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @students = Student.includes(group: :chapter).where(chapters: {organization_id: @selected_organization_id}).order(:last_name, :first_name).all
      else
        @students = Student.order(:last_name, :first_name).all
      end

      if not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @subjects = Subject.where(organization: @selected_organization_id)
      else
        @subjects = policy_scope Subject
      end

      unless params[:organization_select]
        @selected_organization_id = @organizations.first.id
      end
      unless params[:subject_select]
        @subject = @subjects.first.id
      end

      # figure 3: Histograms (Trellis) for the seven skills that are evaluated
      # multiple series (1 per group) per histogram;
      # x-axis: nr. of lessons
      # y-axis: average score
      # series = [{skill : skill_name, series : [{name : group_name, data : [[x, y], ..]}]}]
      series3 = performance_per_skill
      @count = series3.count
      @series3 = series3.to_json

    end

    def third
      @subject = params[:subject_select]

      @organizations = policy_scope Organization
      if not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @chapters = Chapter.where(organization_id: @selected_organization_id)
      else
        @chapters = Chapter.where(organization: @organizations)
      end

      unless params[:organization_select]
        @selected_organization_id = @organizations.first.id
      end

      # figure 8: Average performance per group by days in program
      # Rebecca requested a Trellis per Group
      series8 = performance_per_group
      @count = series8.count
      @series8 = series8.to_json
    end

    def performance_per_group
      groups = if not @selected_chapter_id.nil? and not @selected_chapter_id == '' and not @selected_chapter_id == 'All'
        Group.where(chapter_id: @selected_chapter_id)
        # lessons = Lesson.joins(:grades).includes(:group).group('lessons.id').where(groups: {chapter_id: @selected_chapter_id})
      else
        # lessons = Lesson.joins(:grades, group: :chapter).group('lessons.id').where(chapters: {organization_id: @selected_organization_id})
        Group.joins(:chapter).where(chapters: {organization_id: @selected_organization_id})
      end
      conn = ActiveRecord::Base.connection.raw_connection

      groups
        .map {|group| {group_name: group.group_chapter_name, result: conn.exec(average_mark_in_group_lessons(group)).values}}
        .select {|group_result| group_result[:result].length > 0}
        .map do |group_result|
          group_series = []
          group_series << {
            name: group_result[:group_name],
            data: group_result[:result],
            regression: group_result[:result].length > 1,
            color: get_color(0),
            regressionSettings: {
              type: 'polynomial',
              order: 4,
              color: get_color(0),
              name: "#{t(:group)} #{group_result[:group_name]} - Regression",
              lineWidth: 1
          }}
          {group: t(:group) + ' ' + group_result[:group_name], series: group_series}
        end
    end

    def performance_per_skill
      series = []
      if @selected_student_id.present? && @selected_student_id != 'All'
        lessons = Lesson.includes(:grades).where(grades: {student_id: @selected_student_id})
      elsif @selected_group_id.present? && @selected_group_id != 'All'
        lessons = Lesson.where(group_id: @selected_group_id)
      elsif @selected_chapter_id.present? && @selected_chapter_id != 'All'
        lessons = Lesson.includes(:group).where(groups: {chapter_id: @selected_chapter_id})
      elsif @selected_organization_id.present? && @selected_organization_id != 'All'
        lessons = Lesson.includes(group: :chapter).where(chapters: {organization_id: @selected_organization_id})
      else
        lessons = Lesson.where(group: @groups)
      end

      return [] if lessons.empty?

      conn = ActiveRecord::Base.connection.raw_connection
      groups = {}
      query_result = conn.exec(performance_per_skill_in_lessons_query(lessons)).values
      result = query_result.reduce({}) do |acc, e|
        group_id = e[-1]
        group_name = groups[group_id] ||= Group.find(group_id).group_chapter_name
        skill_name = e[-2]
        acc.tap do |a|
          if a.has_key?(skill_name)
            if a[skill_name].has_key?(group_name)
              a[skill_name][group_name].push({x: e[0], y: e[1], lesson_url: Rails.application.routes.url_helpers.lesson_path(e[2]), date: e[3]})
            else
              a[skill_name][group_name] = [{x: e[0], y: e[1], lesson_url: Rails.application.routes.url_helpers.lesson_path(e[2]), date: e[3]}]
            end
          else
            a[skill_name] = { group_name => [{x: e[0], y: e[1], lesson_url: Rails.application.routes.url_helpers.lesson_path(e[2]), date: e[3]}] }
          end
        end
      end

      # Calculation is done, now convert the series_hash to something HighCharts understands
      result.each do |skill_name, hash|
        # regression = RegressionService.new.skill_regression skill_name, hash.values.map(&:length).max

        skill_series = []
        hash.each_with_index do |(group, array), index|
          skill_series << {name: "#{t(:group)} #{group}", data: array, color: get_color(index), regression: array.length > 1, regressionSettings: {
            type: 'polynomial',
            order: 4,
            color: get_color(index),
            name: "#{t(:group)} #{group} - Regression",
            lineWidth: 1
          }}
        end

        # skill_series << {name: t(:regression_curve), data: regression, color: '#FF0000', lineWidth: 1, marker: {enabled: false}}
        series << {skill: skill_name, series: skill_series}
      end
      series
    end

    private

    def colors
      %w(#7cb5ec #434348 #90ed7d #f7a35c #8085e9 #f15c80 #e4d354 #2b908f #f45b5b #91e8e1)
      %w(#7cb5ec #434348 #90ed7d #f7a35c #8085e9 #f15c80 #e4d354 #2b908f #f45b5b #91e8e1)
    end

    def get_color(i)
      colors[i % colors.length]
    end
  end
end

