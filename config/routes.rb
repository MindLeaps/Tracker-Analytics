MindleapsAnalytics::Engine.routes.draw do
  match 'general' => 'general#index', via: [:get, :post], as: :general_analytics

  match 'subject' => 'subject#index', via: [:get, :post], as: :subject_analytics

  match 'group' => 'group#index', via: [:get, :post], as: :group_analytics

  get 'find/update_chapters'

  get 'find/update_groups'

  get 'find/update_students'

  get 'find/update_subjects'

  root to: 'general#index'
end
