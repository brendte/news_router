require 'rbconfig'
HOST_OS = RbConfig::CONFIG['host_os']

source 'https://rubygems.org'

gem 'rails', '3.1.11'

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.1.4'
  gem 'coffee-rails', '~> 3.1.1'
  gem 'uglifier', '>= 1.0.3'
end

gem 'jquery-rails'

# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'

# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'
group :development do
  gem 'sqlite3'
  gem 'annotate', '>=2.5.0'
  gem 'haml-rails', '>= 0.3.4'
  gem 'jazz_hands'
end

group :test do
  # Pretty printed test output
  gem 'turn', require: false
end
# install a Javascript runtime for linux
#if HOST_OS =~ /linux/i
#  gem 'therubyracer', '>= 0.9.8'
#end

gem 'haml', '>= 3.1.2'
gem 'zurb-foundation'
gem 'typhoeus'
gem 'unicorn'
gem 'kaminari'
gem 'pg'
gem 'devise'
gem 'ruby-stemmer', require: 'lingua/stemmer'
gem 'mongo'
gem 'bson_ext'
gem 'feedzirra'
gem 'figaro'
gem 'rufus-scheduler'
gem 'girl_friday'


