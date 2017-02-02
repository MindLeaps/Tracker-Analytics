MindleapsAnalytics::Engine.routes.draw do

  get 'main/first'

  post 'main/first'

  get 'main/second'

  post 'main/second'

  get 'main/third'

  get 'find/update_chapters'

  get 'find/update_groups'

  get 'find/update_students'

  root to: 'main#first'
end
