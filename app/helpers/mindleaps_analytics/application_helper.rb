module MindleapsAnalytics
  module ApplicationHelper

    def renderSeries (series)
      string = '['
      series.each do |entry|
        string += '{'
        string += 'name: ' + "'" + entry[:name] + "',"
        if entry[:data].first.class == Array
          string += 'data: ' + entry[:data].to_s
        else
          string += 'data: ['
          entry[:data].each do |point|
            string += '{'
            string += 'name: ' + "'" + point[:name] + "',"
            string += 'x: ' + point[:x].to_s + ','
            string += 'y: ' + point[:y].to_s
            string += '}'
            string += ',' unless point == entry[:data].last
          end
          string += ']'
        end
        string += '}'
        string += ',' unless entry == series.last
      end
      string += ']'
      return string.html_safe
    end

  end
end
