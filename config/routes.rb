MindleapsAnalytics::Engine.routes.draw do

  resources :regression_parameters
  get 'main/first'

  post 'main/first'

  get 'main/second'

  post 'main/second'

  get 'main/third'

  post 'main/third'

  get 'find/update_chapters'

  get 'find/update_groups'

  get 'find/update_students'

  get 'find/update_subjects'

  root to: 'main#first'
end
