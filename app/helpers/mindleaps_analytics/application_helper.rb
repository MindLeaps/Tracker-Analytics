module MindleapsAnalytics
  module ApplicationHelper

    def renderSeries (series)
      string = '['
      series.each do |entry|
        string += '{'
        string += 'name: ' + "'" + entry[:name] + "',"
        string += 'data: ' + entry[:data].to_s
        string += '}'
        string += ',' unless entry == series.last
      end
      string += ']'
      return string.html_safe
    end

  end
end
