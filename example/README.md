# Sample app

This is for development and testing purposes.

## Getting started

The sample app uses Bundler and MySQL to power a trivial single-file Rails application:

```sh
# cd example
bundle install
./setup_database.sh

# To launch a console:
bundle exec pry -r ./app.rb

# To start a server:
bundle exec rackup config.ru
```
