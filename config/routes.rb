MindleapsAnalytics::Engine.routes.draw do
  match 'general' => 'general#index', via: [:get, :post], as: :general_analytics

  match 'subject' => 'subject#index', via: [:get, :post], as: :subject_analytics

  get 'main/third'

  post 'main/third'

  get 'find/update_chapters'

  get 'find/update_groups'

  get 'find/update_students'

  get 'find/update_subjects'

  root to: 'general#index'
end
