MindleapsAnalytics::Engine.routes.draw do
  get 'main/first'

  get 'main/second'

  get 'main/third'

  namespace :mindleaps_analytics do
    get 'main/first'
  end

  namespace :mindleaps_analytics do
    get 'main/second'
  end

  namespace :mindleaps_analytics do
    get 'main/third'
  end

  get 'test', to: 'test#hi'

  root to: 'main#first'
end
