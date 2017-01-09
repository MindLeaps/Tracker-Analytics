# MindleapsAnalytics

## Installation
1. Clone this repo

2. Open the Tracker Core Gemfile and uncomment the line that adds gem mindleaps_analytics

3. Adjust the gem path to where you cloned this repo

4. In the Core directory run:
    ```bash
        bundle install
    ```

5. Uncomment the mount MindleapsAnalytics::Engine line in core's routes.rb file

6. Start the Core server as normal

This should start the Core server and mount Analytics at /analytics route. You can see if it's working by visiting:

localhost:3000/analytics/test

You can define additional routes in the analytics' routes.rb file.

