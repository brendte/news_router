# == Schema Information
#
# Table name: feed_entries
#
#  id           :integer          not null, primary key
#  summary      :text
#  url          :string(255)
#  published_at :datetime
#  guid         :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#  title        :string(255)
#  fetched      :boolean
#  article_id   :integer
#

# Model that stores the body and meta-data for an individual news feed entry in the PostgreSQL db
class FeedEntry < ActiveRecord::Base
  belongs_to :article
end
