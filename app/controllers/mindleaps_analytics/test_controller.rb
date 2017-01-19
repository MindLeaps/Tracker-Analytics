module MindleapsAnalytics
  class TestController < ApplicationController
    def hi
      @some_variable = 'This is the analytics module' # instance variable begin with @ character and are available to the view
      @students = Student.all # Querying all students through ActiveRecord ORM
      render 'test/hi' # rendering a view located in views/test/hi.html.erb - views directory is already assumed and the extension is not necessary to specify
    end

    def sascha

      #render '/sascha'
    end
  end
end
