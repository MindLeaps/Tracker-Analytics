module MindleapsAnalytics
  module ApplicationHelper
    def general_analytics?
      current_page?(general_analytics_url) || current_page?(root_url) || request.fullpath == general_analytics_path
    end

    def subject_analytics?
      current_page?(subject_analytics_url) || request.fullpath == subject_analytics_path
    end

    def group_analytics?
      current_page?(group_analytics_url) || request.fullpath == group_analytics_path
    end

    def link_to_disable_if_current(url)
      return '' if current_page? url

      "href=#{url}"
    end

    def href_to url
      "href=#{url}"
    end
  end
end
