module MindleapsAnalytics
  class ApplicationController < ::ApplicationController # Inheriting from host application controller
    protect_from_forgery with: :exception
  end
end
