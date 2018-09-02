require_dependency "mindleaps_analytics/application_controller"
require 'sql/queries'
include SQL

module MindleapsAnalytics
  class MainController < ApplicationController
    skip_after_action :verify_authorized

    before_action do
      @selected_organization_id = params[:organization_select]
      @selected_chapter_id = params[:chapter_select]
      @selected_group_id = params[:group_select]
      @selected_student_id = params[:student_select]

      @selected_organizations = find_resource_by_id_param @selected_organization_id, Organization
      @selected_chapters = find_resource_by_id_param(@selected_chapter_id, Chapter) { |c| c.where(organization: @selected_organizations) }
      @selected_groups = find_resource_by_id_param(@selected_group_id, Group) { |g| g.where(chapter: @selected_chapters) }
      @selected_students = find_resource_by_id_param(@selected_student_id, Student) { |s| s.where(group: @selected_groups) }
    end

    def first
      @organizations = policy_scope Organization
      if not @selected_organization_id.nil? and not @selected_organization_id == '' and not @selected_organization_id == 'All'
        @chapters = Chapter.where(organization_id: @selected_organization_id)
      else
        @chapters = policy_scope Chapter
      end

      if not @selected_chapter_id.nil? and not @selected_chapter_id == '' and not @selected_chapter_id == 'All'
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
        @students = policy_scope Student.order(:last_name, :first_name)
      end

      res2 = assesments_per_month
      @categories2 = res2[:categories].to_json
      @series2 = res2[:series].to_json


      @series4 = histogram_of_student_performance.to_json

      @series5 = histogram_of_student_performance_change.to_json

      @series6 = histogram_of_student_performance_change_by_gender.to_json

      @series10 = average_performance_per_group_by_lesson.to_json

      # Removed beacuse it wasn't used by MindLeaps
      # @series9 = performance_data_for_each_student_versus_time_in_program.to_json

      fresh_when etag: [@categories2, @series2, @series4, @series5, @series6, @series10]
    end

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


    def average_performance_per_group_by_lesson
      groups = Array(get_groups_for_average_performance)

      conn = ActiveRecord::Base.connection.raw_connection
      series = groups.map do |group|
        result = conn.exec(average_mark_in_group_lessons(group)).values
        { name: "#{t(:group)} #{group.group_chapter_name}", data: result }
      end

      p_t1 = 0.05565
      p_t2 = -0.00075043
      p_t3 = 4.2898e-06
      p_t4 = -8.4405e-09
      p_age = 0.048271
      # No intercept value given bij Patrick, so we use the average over all the group values here
      # = Average(3,928; 3,7858; 4,012; 3,9965; 4,3559; 3,3744)
      p_intercept = 3.909

      age = 13

      # regression_values = series.pluck(:data).map(&:length).max

      # regression = Array.new(regression_values) do |index|
      #   p_intercept + p_t1 * index + p_t2 * index**2 + p_t3 * index**3 + p_t4 * index**4 + p_age * age
      # end

      # series << {name: t(:regression_curve), data: regression, color: '#FF0000', lineWidth: 1, marker: {enabled: false}}
      series
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

    def histogram_of_student_performance_change_by_gender
      conn = ActiveRecord::Base.connection.raw_connection
      male_students = @selected_students.where(gender: 'M')
      female_students = @selected_students.where(gender: 'F')

      result= []

      if male_students.length.positive?
        result << { name: "#{t(:gender)} M", data: conn.exec(performance_change_query(male_students)).values }
      end

      if female_students.length.positive?
        result << { name: "#{t(:gender)} F", data: conn.exec(performance_change_query(female_students)).values }
      end

      result
    end

    def histogram_of_student_performance_change
      conn = ActiveRecord::Base.connection.raw_connection

      if @selected_students.blank?
        res = []
      else
        res = conn.exec(performance_change_query(@selected_students)).values
      end
      [{name: t(:frequency_perc), data: res}]
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

    def histogram_of_student_performance
      conn = ActiveRecord::Base.connection.raw_connection
      if @selected_students.blank?
        res = []
      else
        res = conn.exec("select COALESCE(rounded, 0)::INT as mark, count(*) * 100 / (sum(count(*)) over ())::FLOAT as percentage
                            from (select s.id, round(avg(mark)) as rounded
                                  from students as s
                                    left join grades as g
                                      on s.id = g.student_id
                                    left join grade_descriptors as gd
                                      on gd.id = g.grade_descriptor_id
                                  WHERE s.id IN (#{@selected_students.pluck(:id).join(', ')})
                                  GROUP BY s.id
                            ) as student_round_mark
                          GROUP BY mark
                          ORDER BY mark;").values
      end

      [{name: t(:frequency_perc), data: res}]
    end

    def assesments_per_month
      conn = ActiveRecord::Base.connection.raw_connection
      lesson_ids = Lesson.where(group_id: @selected_students.map(&:group_id).uniq).pluck(:id)

      if lesson_ids.blank?
        res = []
      else
        res = conn.exec("select to_char(date_trunc('month', l.date), 'YYYY-MM') as month, count(distinct(l.id, g.student_id)) as assessments
                                      from lessons as l
                                        inner join grades as g
                                          on l.id = g.lesson_id
                                        inner join groups as gr
                                          on gr.id = l.group_id
                                      where l.id IN (#{lesson_ids.join(', ')})
                                      group by month
                                      order by month;").values
      end

      {
        categories: res.map { |e| e[0] },
        series: [{ name: t(:nr_of_assessments), data: res.map { |e| e[1] } }]
      }
    end

    private

    def get_groups_for_average_performance
      if @selected_student_id.present? && @selected_student_id != 'All'
        Student.find(@selected_student_id).group
      elsif @selected_group_id.present? && @selected_group_id != 'All'
        Group.includes(:chapter).find(@selected_group_id)
      elsif @selected_chapter_id.present? && @selected_chapter_id != 'All'
        Group.includes(:chapter).where(chapter_id: @selected_chapter_id)
      elsif @selected_organization_id.present? && @selected_organization_id != 'All'
        Group.includes(:chapter).joins(:chapter).where(chapters: { organization_id: @selected_organization_id })
      else
        @groups.includes(:chapter)
      end
    end

    def find_resource_by_id_param(id, resource_class)
      return resource_class.where(id: id) unless all_selected?(id)
      return policy_scope(yield resource_class) if block_given?

      policy_scope resource_class
    end

    def all_selected?(id_selected)
      id_selected.nil? || id_selected == '' || id_selected == 'All'
    end

    def colors
      %w(#7cb5ec #434348 #90ed7d #f7a35c #8085e9 #f15c80 #e4d354 #2b908f #f45b5b #91e8e1)
      %w(#7cb5ec #434348 #90ed7d #f7a35c #8085e9 #f15c80 #e4d354 #2b908f #f45b5b #91e8e1)
    end

    def get_color(i)
      colors[i % colors.length]
    end
  end
end

