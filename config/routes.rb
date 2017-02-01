MindleapsAnalytics::Engine.routes.draw do

  get 'main/first'

  get 'main/second'

  get 'main/third'

  get 'find/update_students'

  root to: 'main#first'
end
