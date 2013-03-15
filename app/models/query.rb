# == Schema Information
#
# Table name: queries
#
#  id               :integer          not null, primary key
#  user_id          :integer
#  created_at       :datetime
#  updated_at       :datetime
#  body             :text
#  indexed          :boolean
#  euclidean_length :float
#  threshold        :float
#

# Model that stores the free text string (body) representing a user's stored query, along with the minimum score threshold that
# a document's score against the query must reach in order for the document to be routed to the user; stored in the PostgreSQL db
class Query < ActiveRecord::Base
  include Indexable

  belongs_to :user

  # any time a query is saved, call ROUTE_NEW_QUERY on it to make sure all matching articles are added to the user's
  # articles collection
  after_save :route_me

  def self.build_full(params, user)
    threshold = params[:query][:threshold].to_f
    params[:query][:threshold] = '1.0' if threshold > 1.0
    params[:query][:threshold] = '0.1' if threshold < 0.1
    params[:query].merge!({indexed: false, euclidean_length: 0.0})
    query = self.new(params[:query])
    query.user = user
    query
  end

  private

  def route_me
    #ROUTE_NEW_QUERY is an asynchronous girl_friday which runs as a "background" job the job to score and route all articles against the query
    # this prevents a long-running call to ArticleRouter#route_on_new_query from blocking the main thread
    ROUTE_NEW_QUERY << {query_id: self.id}
  end
end
