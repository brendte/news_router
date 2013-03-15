# == Schema Information
#
# Table name: feeds
#
#  id         :integer          not null, primary key
#  feed_url   :string(255)
#  etag       :string(255)
#  created_at :datetime
#  updated_at :datetime
#

# Model that stores the body and meta-data for a news feed in the PostgreSQL db
class Feed < ActiveRecord::Base
end
